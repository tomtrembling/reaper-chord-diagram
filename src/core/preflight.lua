--- Whether the action may run, and what to say when it may not.
---
--- Pure: it is handed FACTS about the machine and answers with a message, so
--- every refusal the user can see is decided here and specced here. Gathering
--- those facts needs the REAPER API and therefore lives in the entry script;
--- deciding what they mean does not, and this is the one place that does it.
local version = require("core.version")

local M = {}

--- @class Environment what the entry script observed before doing anything
--- @field host string|nil the REAPER version, as `GetAppVersion` reports it
--- @field missing string[] required extensions that are not installed, by name
--- @field unusable { extension: string, call: string }|nil installed, too old
--- @field projectSaved boolean
--- @field selected integer media items selected, of any kind
--- @field empty integer how many of those are empty items

--- Why the action will not run, or nil if it will.
--- @param env Environment
--- @return string|nil refusal
function M.refusal(env)
  -- THE HOST IS ASKED ABOUT FIRST, before the extensions it would have to run.
  -- On a REAPER too old for ReaImGui, ReaImGui is usually missing as well —
  -- and "install ReaImGui" would send the user to install something their
  -- REAPER will not load. The cause is named rather than the symptom.
  --
  -- A host that will not say its version is NOT refused. It is reported as
  -- unknown in the diagnostics and the action goes ahead: refusing on an
  -- absent fact would turn a reporting gap into a plugin that does not run.
  if env.host and not version.atLeast(env.host, version.MIN_REAPER) then
    return string.format(
      "This action needs REAPER %s or newer.\n\nThis is REAPER %s.",
      version.MIN_REAPER, env.host)
  end
  if #env.missing > 0 then
    -- Named individually, because ReaPack does not reliably install these and
    -- "a dependency is missing" is not something a user can act on. More than
    -- one can be absent, so the sentence has to survive being about two things.
    return "This action needs " .. table.concat(env.missing, " and ")
      .. ".\n\nInstall " .. (#env.missing == 1 and "it" or "them")
      .. " through ReaPack (Extensions > ReaPack > Browse packages), then "
      .. "restart REAPER."
  end
  if env.unusable then
    -- Installed, but this build of it does not have a call the plugin makes.
    -- The name of the call is the fact that turns a bug report into a version
    -- number, so it is in the message rather than only in the diagnostics.
    -- `adapter.imgui` says the same thing in the same shape about ReaImGui.
    return string.format(
      "This version of %s does not provide %s, which the chord diagram needs."
      .. "\n\nUpdate %s through ReaPack and restart REAPER.",
      env.unusable.extension, env.unusable.call, env.unusable.extension)
  end
  if not env.projectSaved then
    return "Save the project first.\n\nDiagrams are stored beside the project "
      .. "file so they travel with it."
  end
  if env.selected == 0 then
    return "Select an empty item first.\n\nInsert one with "
      .. "Insert > Empty item, then select it."
  end
  if env.selected > 1 then
    return "Select exactly one item.\n\n" .. env.selected .. " are selected, "
      .. "and this action will not pick one for you."
  end
  if env.empty == 0 then
    return "That is not an empty item.\n\nThis action attaches a diagram to an "
      .. "empty item, so an audio or MIDI item is never altered."
  end
  return nil
end

return M
