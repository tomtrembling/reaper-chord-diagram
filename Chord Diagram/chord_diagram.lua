--[[
@description Chord Diagram
@version 0.12.0
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
    - Type the chord as a string — x32010, or 10-12-12-11-10-10 above the ninth
      fret — and the grid redraws as you type.
    - Or click a cell to place a finger and click it again to remove it, click
      above the nut to ring a string open or mute it, and the chord string
      writes itself.
    - Drag across the strings at a fret to lay a barre over them, as far as the
      finger reaches — all six or only two. Click the bar to take it away. A
      barre is only ever drawn because you drew it, and laying one moves no
      finger you have already placed.
    - Type a name. It is drawn as the diagram's title and becomes the item's
      name, so the chord is findable in the Media Item Manager.
    - The first fret box says where the top of the grid sits. It fills itself
      in; change it to frame the chord where you think of it, and press Auto to
      hand the choice back.
    - Press Apply to write the diagram to the item, or Cancel or Escape to back
      out and leave the item exactly as it was.
    - Run it again on the same item to edit the chord: the voicing is stored on
      the item, so it comes back already on the grid, and copying the item
      copies the chord with it.

  A barre cannot be written in a chord string, so retyping the text of a chord
  that has one keeps it.

  IF SOMETHING GOES WRONG, run the action "Chord Diagram: copy diagnostics". It
  puts a plain-text report on your clipboard — versions, paths, what is selected
  and the last error this action showed — for pasting into a message.

  Requires REAPER 6.44 or newer, js_ReaScriptAPI and ReaImGui 0.9 or newer.
@changelog
  0.12.0 Every refusal now explains itself: nothing selected, several items
        selected, an item that is not empty, a missing extension named
        individually, or a REAPER too old, each with its own message and
        nothing modified. A second action, "Chord Diagram: copy diagnostics",
        copies versions, resolved paths, what is selected and the last error to
        the clipboard for a bug report. A failed write to the item is now
        rolled back rather than leaving a diagram on an item whose chord data
        did not get written.
  0.11.0 Barres, laid across the strings by dragging over them at a fret and
        taken away by clicking the bar. Partial barres span exactly the strings
        you dragged across. Nothing infers a barre and laying one moves no
        finger, so a diagram never claims a fingering you did not choose.
  0.10.0 A text field for the chord string, synced both ways with the grid: type
        and the grid redraws, click and the text rewrites itself. Half-typed
        text changes nothing rather than complaining. A name field is back, and
        the diagram's first fret can be set by hand or left to work itself out.
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
local preflight = require("core.preflight")

local deps = require("adapter.deps")
local dialog = require("adapter.dialog")
local errors = require("adapter.errors")
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
---
--- EVERY REFUSAL IS ALSO RECORDED. The developer cannot run REAPER, so a
--- failure on the tester's machine reaches him only as whatever the tester
--- pastes — and "I ran it and nothing happened" is not enough to act on. The
--- diagnostic action reads the last recorded message back, so the report says
--- what the user was actually told. Recording cannot itself fail; see
--- `adapter.errors`.
local function refuse(message)
  errors.record(message)
  dialog.alert(TITLE, message)
end

--------------------------------------------------------------------------------
-- Preconditions
--
-- Every fact is gathered first and judged afterwards, by `core.preflight`. The
-- checks used to be a ladder of ifs here, which meant the messages the user
-- sees — the whole of user stories 33 to 36 — lived in the one file that cannot
-- be tested on this machine, and got their priority from the order somebody
-- happened to write them in. Two audio items selected answered "that is not an
-- empty item": true, but not the thing to fix.
--
-- Gathering needs the REAPER API and cannot be specced. Deciding does not, and
-- now is.
--------------------------------------------------------------------------------

local projectDir = project.dir()
local items, selected = itemAdapter.selectedEmptyItems()

local refusal = preflight.refusal({
  host = deps.hostVersion(),
  missing = deps.missing(),
  unusable = deps.unusable(),
  projectSaved = projectDir ~= nil,
  selected = selected,
  empty = #items,
})
if refusal then
  return refuse(refusal)
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
  -- The window has a name field again, so this is now what it was always meant
  -- to be — a default for someone who did not want to name the chord — rather
  -- than the only way one could be named.
  if v.name == "" then
    v = voicingOf.setName(v, voicingOf.toText(v))
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

  -- The chunk transformation happens BEFORE the undo block opens. It is pure
  -- string work that can fail, and failing inside the block would open one for
  -- an edit that never starts.
  local updated, chunkError = chunkOf.setImage(chunkText, {
    -- The chord name goes into the item's notes: that is both what REAPER shows
    -- as the empty item's label and what makes it findable in the Item Manager.
    -- A non-empty notes block is also what makes IMGRESOURCEFLAGS take effect.
    filename = relativePath,
    flags = IMGRESOURCEFLAGS,
    notes = v.name,
  })
  if not updated then
    return refuse("The item's state could not be updated.\n\n" .. tostring(chunkError)
      .. "\n\nThe item is unchanged.")
  end

  -- Both writes go inside the one undo block, so the picture and the data that
  -- produced it can never be one Ctrl+Z out of step with each other. Their
  -- order, and what happens if the second one fails, are `adapter.item`'s —
  -- the rule and the code that must obey it belong in the same place.
  local ok, err = itemAdapter.asUndoableEdit("Chord diagram: " .. v.name, function()
    return itemAdapter.writeChord(item, chunkText, updated, voicingOf.encode(v))
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
