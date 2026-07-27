--[[
@description Chord Diagram
@version 0.8.0
@author Tom Trembling
@about
  Capture a guitar chord voicing and pin its diagram to a point in the timeline,
  without leaving REAPER.

  Select an empty item, run this action, and type the voicing as a chord string
  such as x32010 (low E to high E, x for a muted string, 0 for an open one) plus
  a name. The plugin renders a chord diagram into the project folder and
  attaches it to the item, where it displays in the arrange view and scales as
  the item is resized.

  HOW TO USE
    - Save the project first; the image is stored beside it.
    - Insert an empty item on a track and select exactly one.
    - Run this action, type the chord and a name, and press OK.
    - For a chord at the tenth fret or above, separate the positions:
      10-12-12-11-10-10. The diagram frames itself from the lowest fretted fret
      and says which one it is.
    - Run it again on the same item to edit the chord: the voicing is stored on
      the item, so it comes back already filled in, and copying the item copies
      the chord with it.

  Requires js_ReaScriptAPI.
@changelog
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
  return refuse("This action needs " .. table.concat(missing, ", ") ..
    ".\n\nInstall it through ReaPack (Extensions > ReaPack > Browse packages),"
    .. " then restart REAPER.")
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
-- the chord that is here". Both reads happen once, here: the dialog below is
-- modal, so nothing can change the item between here and the write.
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
-- Input
--------------------------------------------------------------------------------

-- The label carries both notations because this dialog has nowhere else to put
-- help, and a guitarist typing a chord at the twelfth fret needs to be told the
-- separated form exists. It must contain no comma: `dialog.prompt` joins the
-- labels with commas, so one inside a label would invent a field.
local answers = dialog.prompt(TITLE, { "Chord (e.g. x32010 or 10-12-12-11-10-10)", "Name" }, {
  existing and voicingOf.toText(existing) or "",
  existing and existing.name or "",
})
if not answers then
  return -- cancelled; the item is untouched
end

-- Parsed against the existing chord, not from nothing: barres, finger numbers
-- and a base-fret override cannot be written in the text field, so re-typing
-- the text has to merge into what is already there or it deletes them.
local chordText, name = answers[1], answers[2]
local v, parseError = voicingOf.parse(chordText, name, existing)
if not v then
  return refuse(parseError .. "\n\nWrite one position per string, low E to high "
    .. "E: x for muted, 0 for open, or the fret number. For example x32010.\n\n"
    .. "At the tenth fret and above, separate the positions with hyphens so "
    .. "each one is unambiguous: 10-12-12-11-10-10.")
end

-- The name is drawn on the diagram and is what identifies the item in REAPER,
-- so an unnamed chord falls back to its own chord string rather than nothing.
if v.name == "" then
  v.name = voicingOf.toText(v)
end

--------------------------------------------------------------------------------
-- Render and attach
--------------------------------------------------------------------------------

local filename = voicingOf.fingerprint(v) .. ".png"
local relativePath = project.relativeImagePath(filename)
local absolutePath = project.absoluteImagePath(projectDir, filename)

project.ensureImageFolder(projectDir)

-- The filename is a hash of the voicing, so an identical chord elsewhere in the
-- project already has its image on disk and there is nothing to render.
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
  -- the dialog opened, and REAPER serialises extended state into that same
  -- chunk. Storing the voicing first and writing the chunk second would hand
  -- REAPER a chunk carrying the PREVIOUS voicing and quietly undo the edit.
  -- Chunk, then extended state. Do not swap these two for tidiness.
  if not itemAdapter.setChunk(item, updated) then
    return false, "REAPER refused the updated item state."
  end

  -- Both writes are inside the one undo block, so the picture and the data that
  -- produced it can never be one Ctrl+Z out of step with each other.
  if not itemAdapter.setStoredVoicing(item, voicingOf.encode(v)) then
    return false, "REAPER refused the item's chord data."
  end
  return true
end)

if not ok then
  refuse("The chord could not be attached to the item.\n\n" .. tostring(err))
end
