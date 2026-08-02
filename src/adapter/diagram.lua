--- Getting a voicing's diagram onto disk and onto the item.
---
--- EXTRACTED FROM THE ENTRY SCRIPT IN SLICE 010, when a second and a third
--- caller appeared: the editor applying a chord, the editor silently repairing
--- one whose image has gone, and the project-wide sweep repairing all of them.
--- Three copies of "hash the voicing, render if the file is absent, rewrite the
--- chunk, store the voicing" is three chances to write the two writes in the
--- wrong order, and the order is load-bearing — see `adapter.item.writeChord`.
---
--- What this module does NOT do is open an undo block. That is the caller's,
--- because the editor wants one block per chord and the sweep wants one block
--- for the whole project, and a module that decided for them could not give
--- both.
local chunkOf = require("core.chunk")
local layout = require("core.layout")
local voicingOf = require("core.voicing")

local itemAdapter = require("adapter.item")
local lice = require("adapter.lice")
local project = require("adapter.project")

local M = {}

--- Settled rendering configuration, established over four runs on the tester's
--- machine in slice 002. Do not re-derive these; see
--- `issues/done/002-tracer-bullet-chord-on-item.md`.
local CANVAS = 1024 -- square, power of two
local IMGRESOURCEFLAGS = 3 -- the only value that never repeats the image

--- Where this voicing's diagram lives.
---
--- THE FILENAME IS DERIVED, NOT REMEMBERED. It is a hash of the voicing, so the
--- same chord always names the same file: identical voicings across a project
--- share one image, an edit produces a new name rather than overwriting one
--- REAPER may still be displaying, and — the point of this slice — rebuilding a
--- lost image reproduces exactly the filename the item is already pointing at.
--- Recovery is therefore idempotent by construction rather than by bookkeeping.
--- @param projectDir string
--- @param v Voicing
--- @return string relative the reference stored in the item
--- @return string absolute the path the renderer writes to
function M.imagePaths(projectDir, v)
  local filename = voicingOf.fingerprint(v) .. ".png"
  return project.relativeImagePath(filename),
    project.absoluteImagePath(projectDir, filename)
end

--- Is this voicing's diagram already on disk?
--- @param projectDir string
--- @param v Voicing
--- @return boolean
function M.imagePresent(projectDir, v)
  local _, absolute = M.imagePaths(projectDir, v)
  return project.exists(absolute)
end

--- Put the diagram for `v` on disk and on the item.
---
--- Renders only when the file is not already there, which is what makes both
--- "apply an unchanged chord" and "sweep a project that is fine" cost nothing.
--- The item is then rewritten either way: RE-LINKING IS NOT SKIPPED WHEN THE
--- IMAGE WAS MISSING, because REAPER has already tried and failed to load that
--- file and setting the chunk again is what makes it look a second time. An
--- image rebuilt but not re-linked would sit correct on disk and invisible in
--- the arrange view, which is the failure this slice exists to prevent.
---
--- MUST BE CALLED INSIDE AN UNDO BLOCK. `adapter.item.writeChord` owns the two
--- writes and rolls the first one back if the second fails, and that rollback
--- is only invisible from inside a block.
--- @param item userdata
--- @param original string the item's chunk as it was read
--- @param v Voicing
--- @param projectDir string
--- @return boolean ok
--- @return string|nil err
function M.attach(item, original, v, projectDir)
  local relative, absolute = M.imagePaths(projectDir, v)

  if not project.exists(absolute) then
    project.ensureImageFolder(projectDir)
    local rendered, renderError = lice.writePNG(layout.compute(v, CANVAS, CANVAS), absolute)
    if not rendered then
      return false, "The diagram could not be rendered.\n\n" .. tostring(renderError)
    end
  end

  -- Pure string work, and it can fail, so it happens before anything is
  -- written rather than half way through the edit.
  local updated, chunkError = chunkOf.setImage(original, {
    -- The chord name goes into the item's notes: that is what REAPER shows as
    -- the empty item's label in the arrange view, and a non-empty notes block is
    -- also what makes IMGRESOURCEFLAGS take effect. It does NOT reach the Media
    -- Item Manager — the tester confirmed that against 0.15.0, and the manager's
    -- name column reads the active take's name, which an empty item has none of.
    -- PRD user story 25 is therefore not met by this; see issue 012.
    filename = relative,
    flags = IMGRESOURCEFLAGS,
    notes = v.name,
  })
  if not updated then
    return false, "The item's state could not be updated.\n\n" .. tostring(chunkError)
      .. "\n\nThe item is unchanged."
  end

  return itemAdapter.writeChord(item, original, updated, voicingOf.encode(v))
end

return M
