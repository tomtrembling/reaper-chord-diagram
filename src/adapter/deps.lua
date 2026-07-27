--- Startup dependency check: what the plugin needs, and whether it is there.
---
--- The required extensions are not reliably auto-installed across ReaPack
--- repositories, so the script names what is missing rather than failing
--- somewhere deep in a call that does not exist. It names them INDIVIDUALLY:
--- "a dependency is missing" is not something a user can act on.
---
--- This module only observes. What the observations MEAN — which of them stops
--- the action and what the user is told — is `core.preflight`, which is pure
--- and therefore specced.
local M = {}

--- Everything the plugin needs from an extension.
---
--- `probe` answers "is this installed at all", `calls` answers "is this build
--- of it new enough", one function name at a time. THE SECOND QUESTION IS
--- ANSWERED BY NAME RATHER THAN BY VERSION NUMBER on purpose: a version floor
--- for js_ReaScriptAPI would be a number invented on a machine where REAPER
--- cannot be run, whereas the list below is exactly what `adapter.lice` calls
--- and can be read off it. `adapter.imgui` asks the same question of ReaImGui
--- the same way, against its own list.
local REQUIRED = {
  {
    name = "js_ReaScriptAPI",
    probe = "JS_LICE_CreateBitmap",
    versionCall = "JS_ReaScriptAPI_Version",
    -- Every js call `adapter.lice` makes UNGUARDED. The ones it already wraps
    -- in pcall are deliberately absent: it survives their being missing, so
    -- their absence is not a reason to refuse to start.
    calls = {
      "JS_LICE_CreateBitmap",
      "JS_LICE_Clear",
      "JS_LICE_FillRect",
      "JS_LICE_FillCircle",
      "JS_GDI_CreateFont",
      "JS_LICE_CreateFont",
      "JS_LICE_SetFontFromGDI",
      "JS_LICE_DrawText",
      "JS_LICE_WritePNG",
    },
  },
  {
    -- Probed by the one function every ReaImGui release has had, so this answers
    -- "is ReaImGui installed at all". Which of its two binding styles the
    -- install supports, and whether it can provide the API version the window
    -- is written against, are separate questions, and `adapter.imgui` is the
    -- only place that asks them.
    name = "ReaImGui",
    probe = "ImGui_CreateContext",
    calls = {},
  },
}

--- @param name string
--- @return boolean
local function exists(name)
  local ok, present = pcall(reaper.APIExists, name)
  return ok and present == true
end

--- Which required extensions are absent?
--- @return string[]
function M.missing()
  local absent = {}
  for _, dep in ipairs(REQUIRED) do
    if not exists(dep.probe) then
      absent[#absent + 1] = dep.name
    end
  end
  return absent
end

--- An extension that is installed but does not provide a call the plugin makes.
---
--- Answers the first one found, since one name is enough to identify the build
--- and a list of them would be the same fact repeated.
--- @return { extension: string, call: string }|nil
function M.unusable()
  for _, dep in ipairs(REQUIRED) do
    if exists(dep.probe) then
      for _, call in ipairs(dep.calls) do
        if not exists(call) then
          return { extension = dep.name, call = call }
        end
      end
    end
  end
  return nil
end

--- The installed version of one extension, for the diagnostic report.
---
--- ISOLATED HERE BECAUSE IT CANNOT BE CONFIRMED FROM THIS MACHINE. Every
--- version call is guarded twice — the name is probed, then the call itself is
--- wrapped — so an extension that reports its version differently, or not at
--- all, produces "unknown" in the report rather than an error in the action
--- that was trying to explain an error. Queued for confirmation in REAPER.
--- @param name string
--- @return string|nil
function M.version(name)
  for _, dep in ipairs(REQUIRED) do
    if dep.name == name and dep.versionCall and exists(dep.versionCall) then
      local ok, value = pcall(reaper[dep.versionCall])
      if ok and value ~= nil then
        if type(value) == "number" then
          return string.format("%.3f", value)
        end
        return tostring(value)
      end
    end
  end
  return nil
end

--- Is this extension installed?
--- @param name string
--- @return boolean
function M.installed(name)
  for _, dep in ipairs(REQUIRED) do
    if dep.name == name then
      return exists(dep.probe)
    end
  end
  return false
end

--- The host's version, as REAPER reports it — "7.09/OSX64".
---
--- The platform suffix is kept rather than trimmed: the project's whole risk is
--- that the developer is on macOS and the user on Windows, so which of the two
--- a report came from is the first thing worth knowing. `core.version.atLeast`
--- reads the leading numbers and ignores the rest.
--- @return string|nil
function M.hostVersion()
  local ok, value = pcall(reaper.GetAppVersion)
  if not ok or value == nil or value == "" then
    return nil
  end
  return tostring(value)
end

return M
