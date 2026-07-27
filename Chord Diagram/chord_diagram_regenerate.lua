--[[
@description Chord Diagram: regenerate missing diagrams
@version 0.13.0
@author Tom Trembling
@about
  Rebuilds every chord diagram image that has gone missing from this project,
  for when a whole folder has disappeared — a project copied to another machine
  without it, or the images tidied away as "unused files".

  Every chord is stored on its item as data, and the picture is only ever
  derived from it, so a lost image is a file that has not been written yet
  rather than something that is gone. This action writes them all again.

  HOW TO USE
    - Open the project and save it, if it has never been saved.
    - Run this action. Nothing needs to be selected.
    - It reports how many diagrams it rebuilt, including when the answer is
      none — which tells you the images are where they should be and the
      problem is somewhere else.

  Images that are already there are left alone, items carrying no chord are
  skipped, and a chord this version cannot read is reported and NOT written to.
  The whole sweep is one undo step.
@changelog
  0.13.0 First release, alongside Chord Diagram 0.13.0.
--]]

--------------------------------------------------------------------------------
-- Module loading
--
-- The same bootstrap as the other two actions, and deliberately a COPY rather
-- than something shared: a module that finds the modules has to be found first.
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

local preflight = require("core.preflight")
local recovery = require("core.recovery")

local deps = require("adapter.deps")
local diagram = require("adapter.diagram")
local dialog = require("adapter.dialog")
local errors = require("adapter.errors")
local itemAdapter = require("adapter.item")
local project = require("adapter.project")

local TITLE = "Chord Diagram: regenerate"

--- @param message string
local function refuse(message)
  errors.record(message)
  dialog.alert(TITLE, message)
end

--------------------------------------------------------------------------------
-- Preconditions
--
-- `sweepRefusal` rather than `refusal`: the same installation checks the editor
-- makes, and none of its selection checks, because this action is about every
-- item in the project and never asks what is selected. Both live in
-- `core.preflight` so the two actions cannot end up with different ideas of
-- what a working install is.
--------------------------------------------------------------------------------

local projectDir = project.dir()

local refusal = preflight.sweepRefusal({
  host = deps.hostVersion(),
  missing = deps.missing(),
  unusable = deps.unusable(),
  projectSaved = projectDir ~= nil,
})
if refusal then
  return refuse(refusal)
end

--------------------------------------------------------------------------------
-- Pass one: look, and write nothing
--
-- THIS ACTION IS THE MOST DESTRUCTIVE THING THE PLUGIN DOES. It visits every
-- item in the project and writes to the ones it repairs, and it is run
-- precisely when something is already broken — so the whole of it is arranged
-- so that deciding and writing are separate.
--
-- Nothing below touches an item. It reads what each one carries, asks
-- `core.recovery` — which is pure, and specced — what that means, and builds a
-- list of the ones that genuinely need an image. Everything else is counted and
-- left exactly as it was: an item with no chord, a chord this version cannot
-- read, a chord whose image is already on disk.
--------------------------------------------------------------------------------

local work = {}
local tally = { regenerated = 0, intact = 0, damaged = 0, failed = 0 }

for _, item in ipairs(itemAdapter.allItems()) do
  local plan = recovery.plan(itemAdapter.storedVoicing(item))

  if plan.status == recovery.DAMAGED then
    tally.damaged = tally.damaged + 1
    errors.record("Chord data could not be read during regeneration: "
      .. tostring(plan.reason))
  elseif plan.status == recovery.CHORD then
    if diagram.imagePresent(projectDir, plan.voicing) then
      -- Already there, so it is not rewritten. An image whose filename is a
      -- hash of the voicing that made it cannot be out of date.
      tally.intact = tally.intact + 1
    else
      local chunkText = itemAdapter.chunk(item)
      if chunkText then
        work[#work + 1] = { item = item, chunk = chunkText, voicing = plan.voicing }
      else
        tally.failed = tally.failed + 1
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Pass two: one undo block, and only if there is anything in it
--
-- ONE BLOCK FOR THE WHOLE SWEEP, so a regeneration the user did not want is one
-- Ctrl+Z rather than forty. Opened only when there is work, so a project that
-- needed nothing does not leave an empty edit in the undo history of somebody
-- who was only checking.
--
-- A FAILURE DOES NOT STOP THE SWEEP. Each item is repaired atomically —
-- `adapter.item.writeChord` puts the chunk back if the second write fails — so
-- there is no half-repaired item to unwind, and the ones that worked are
-- genuinely fixed. Stopping at the first failure would leave the rest of a
-- broken project broken, which is the opposite of what this action is for. The
-- count of failures is reported, and every reason is recorded for the
-- diagnostics action.
--------------------------------------------------------------------------------

if #work > 0 then
  itemAdapter.asUndoableEdit("Chord diagram: regenerate missing diagrams", function()
    for _, job in ipairs(work) do
      local ok, err = diagram.attach(job.item, job.chunk, job.voicing, projectDir)
      if ok then
        tally.regenerated = tally.regenerated + 1
      else
        tally.failed = tally.failed + 1
        errors.record("Regeneration failed for one item: " .. tostring(err))
      end
    end
    return true
  end)
end

dialog.alert(TITLE, recovery.summary(tally))
