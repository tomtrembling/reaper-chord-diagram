--[[
@description Chord Diagram
@version 0.9.0
@author Tom Trembling
@about
  Capture a guitar chord voicing and pin its diagram to a point in the timeline,
  without leaving REAPER.

  Select an empty item, run this action, and build the voicing by clicking a
  fretboard grid. The plugin renders a chord diagram into the project folder and
  attaches it to the item, where it displays in the arrange view and scales as
  the item is resized.

  HOW TO USE
    - Save the project first; the image is stored beside it.
    - Insert an empty item on a track and select exactly one.
    - Run this action. A window opens with a fretboard grid.
    - Click a cell to place a finger; click the same cell again to remove it.
    - Click above the nut to ring a string open, and again to mute it.
    - Press Apply to write the diagram to the item, or Cancel or Escape to back
      out and leave the item exactly as it was.
    - Run it again on the same item to edit the chord: the voicing is stored on
      the item, so it comes back already on the grid, and copying the item
      copies the chord with it.

  A chord reaching past the fifth fret frames itself from its lowest fretted
  fret and says which fret that is. A text field for typing a chord string, a
  name field and barres are the next slices.

  Requires js_ReaScriptAPI and ReaImGui.
@changelog
  0.9.0 The native input dialog is replaced by a window with a clickable
        fretboard grid, drawn from the same layout as the exported image.
        Clicking a cell places or clears a finger; clicking above the nut rings
        a string open or mutes it. Apply writes and closes; Cancel and Escape
        leave the item untouched. Until the next slice adds a name field, a new
        chord is titled with its own chord string.
  0.8.0 High-position chords: the separated form 10-12-12-11-10-10, and a
        diagram that frames itself from the lowest fretted fret with a marker
        saying which fret that is.
  0.7.1 Chords are stored in the item's extended state, which REAPER saves with
        the project, rather than on a custom line in the item state chunk.
  0.7.0 Chords are stored on the item and reloaded for editing; renaming a
        chord no longer means rebuilding it.
  0.6.0 Real voicings typed as a chord string, rendered from the shared layout.
  0.5.0 Spike: settle on IMGRESOURCEFLAGS 3 with the square 1024 canvas.
--]]

--------------------------------------------------------------------------------
-- Module loading
--
-- The pure Lua lives in src/, which is not next to this file in the repository
-- but may be next to it once installed. Both candidates go on the path so the
-- script runs from either layout; packaging decides which one is real.
--------------------------------------------------------------------------------

local SEP = package.config:sub(1, 1)
local scriptPath = select(2, reaper.get_action_context())
local scriptDir = scriptPath:match("^(.*)[/\\][^/\\]*$") or "."

for _, root in ipairs({
  scriptDir .. SEP .. "src",
  scriptDir .. SEP .. ".." .. SEP .. "src",
}) do
  package.path = table.concat({
    root .. SEP .. "?.lua",
    root .. SEP .. "?" .. SEP .. "init.lua",
    package.path,
  }, ";")
end

local voicingOf = require("core.voicing")
local layout = require("core.layout")
local chunkOf = require("core.chunk")

local deps = require("adapter.deps")
local dialog = require("adapter.dialog")
local grid = require("adapter.imgui")
local itemAdapter = require("adapter.item")
local lice = require("adapter.lice")
local project = require("adapter.project")

--------------------------------------------------------------------------------
-- Settled rendering configuration
--
-- Established over four runs on the tester's machine in slice 002. Do not
-- re-derive these; see issues/done/002-tracer-bullet-chord-on-item.md.
--------------------------------------------------------------------------------

local CANVAS = 1024 -- square, power of two
local IMGRESOURCEFLAGS = 3 -- the only value that never repeats the image

local TITLE = "Chord Diagram"

--- Stop with a message the user can act on, having changed nothing.
local function refuse(message)
  dialog.alert(TITLE, message)
end

--------------------------------------------------------------------------------
-- Preconditions
--------------------------------------------------------------------------------

local missing = deps.missing()
if #missing > 0 then
  -- More than one extension can be missing now that ReaImGui is required, so
  -- the sentence has to survive being about two things.
  return refuse("This action needs " .. table.concat(missing, " and ") ..
    ".\n\nInstall " .. (#missing == 1 and "it" or "them") .. " through ReaPack "
    .. "(Extensions > ReaPack > Browse packages), then restart REAPER.")
end

local projectDir = project.dir()
if not projectDir then
  return refuse("Save the project first.\n\nDiagrams are stored beside the "
    .. "project file so they travel with it.")
end

local items, selected = itemAdapter.selectedEmptyItems()
if selected == 0 then
  return refuse("Select an empty item first.\n\nInsert one with "
    .. "Insert > Empty item, then select it.")
end
if #items == 0 then
  return refuse("That is not an empty item.\n\nThis action attaches a diagram "
    .. "to an empty item, so an audio or MIDI item is never altered.")
end
if selected > 1 then
  return refuse("Select exactly one item.\n\n" .. selected .. " are selected, "
    .. "and this action will not pick one for you.")
end

local item = items[1]

--------------------------------------------------------------------------------
-- What the item already carries
--
-- The item's stored voicing is the source of truth; the PNG is a derivative.
-- Reading it back is what turns this action from "create a chord" into "edit
-- the chord that is here". Both reads happen once, here, and the chunk read in
-- particular is deliberately taken BEFORE the window opens: the window is not
-- modal, so this action holds a snapshot of the item taken at the moment the
-- user asked to edit it. That is the one-shot lifecycle the PRD asks for — the
-- window edits the chord it was opened on, and nothing watches the selection.
--
-- The voicing comes from the item's extended state and the image fields from its
-- state chunk. They are two different mechanisms because REAPER offers exactly
-- one of each: the image is a chunk field it defines, and the voicing is ours to
-- put somewhere it has promised to keep.
--------------------------------------------------------------------------------

local chunkText = itemAdapter.chunk(item)
if not chunkText then
  return refuse("REAPER would not hand over the item's state.")
end

local existing, readError
local storedVoicing = itemAdapter.storedVoicing(item)
if storedVoicing then
  existing, readError = voicingOf.decode(storedVoicing)
end
if readError then
  return refuse("This item's chord data could not be read.\n\n" .. readError
    .. "\n\nApplying a chord now would overwrite it.")
end

--------------------------------------------------------------------------------
-- Render and attach
--
-- Runs when the user presses Apply, and only then. Cancel and Escape call
-- nothing at all: `core.voicing` never edits a voicing in place, so backing out
-- leaves the item carrying exactly the chord it was carrying, with no undo to
-- perform and nothing to put back.
--------------------------------------------------------------------------------

local function apply(v)
  -- The name is drawn on the diagram and is what identifies the item in REAPER,
  -- so an unnamed chord falls back to its own chord string rather than nothing.
  --
  -- UNTIL SLICE 007 THAT FALLBACK IS THE ONLY WAY A NEW CHORD IS NAMED. The
  -- native input dialog carried the name and it is gone; the window's name
  -- field is the next slice. A chord reopened for editing keeps whatever name
  -- it already has, because the stored voicing carries it, so this only affects
  -- chords created in this version.
  if v.name == "" then
    v.name = voicingOf.toText(v)
  end

  local filename = voicingOf.fingerprint(v) .. ".png"
  local relativePath = project.relativeImagePath(filename)
  local absolutePath = project.absoluteImagePath(projectDir, filename)

  project.ensureImageFolder(projectDir)

  -- The filename is a hash of the voicing, so an identical chord elsewhere in
  -- the project already has its image on disk and there is nothing to render.
  if not project.exists(absolutePath) then
    local rendered, renderError = lice.writePNG(layout.compute(v, CANVAS, CANVAS), absolutePath)
    if not rendered then
      return refuse("The diagram could not be rendered.\n\n" .. tostring(renderError))
    end
  end

  local ok, err = itemAdapter.asUndoableEdit("Chord diagram: " .. v.name, function()
    -- The chord name goes into the item's notes: that is both what REAPER shows
    -- as the empty item's label and what makes it findable in the Item Manager.
    -- A non-empty notes block is also what makes IMGRESOURCEFLAGS take effect.
    local updated, chunkError = chunkOf.setImage(chunkText, {
      filename = relativePath,
      flags = IMGRESOURCEFLAGS,
      notes = v.name,
    })
    if not updated then
      return false, chunkError
    end

    -- ORDER MATTERS, AND IT IS NOT ARBITRARY. The chunk goes first.
    --
    -- `SetItemStateChunk` replaces the item wholesale from text captured before
    -- the window opened, and REAPER serialises extended state into that same
    -- chunk. Storing the voicing first and writing the chunk second would hand
    -- REAPER a chunk carrying the PREVIOUS voicing and quietly undo the edit.
    -- Chunk, then extended state. Do not swap these two for tidiness.
    if not itemAdapter.setChunk(item, updated) then
      return false, "REAPER refused the updated item state."
    end

    -- Both writes are inside the one undo block, so the picture and the data
    -- that produced it can never be one Ctrl+Z out of step with each other.
    if not itemAdapter.setStoredVoicing(item, voicingOf.encode(v)) then
      return false, "REAPER refused the item's chord data."
    end
    return true
  end)

  if not ok then
    refuse("The chord could not be attached to the item.\n\n" .. tostring(err))
  end
end

--------------------------------------------------------------------------------
-- The window
--
-- This is the last statement the action runs: `adapter.imgui` puts the frame
-- loop on `reaper.defer` and the script body ends here. Everything after Apply
-- happens in the callback above.
--------------------------------------------------------------------------------

local opened, windowError = grid.open({
  title = TITLE,
  -- An item with no chord opens on a blank neck — six muted strings — rather
  -- than on a guess, because the plugin never invents a voicing the user did
  -- not enter.
  voicing = existing or voicingOf.new(),
  onApply = apply,
})

if not opened then
  refuse(tostring(windowError))
end
