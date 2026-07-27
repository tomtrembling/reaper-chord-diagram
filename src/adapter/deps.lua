--- Startup dependency check.
---
--- The required extensions are not reliably auto-installed across ReaPack
--- repositories, so the script names what is missing rather than failing
--- somewhere deep in a call that does not exist.
local M = {}

--- Extensions this slice needs, each identified by a function it provides.
local REQUIRED = {
  { name = "js_ReaScriptAPI", probe = "JS_LICE_CreateBitmap" },
}

--- Which required extensions are absent?
--- @return string[]
function M.missing()
  local absent = {}
  for _, dep in ipairs(REQUIRED) do
    if not reaper.APIExists(dep.probe) then
      absent[#absent + 1] = dep.name
    end
  end
  return absent
end

return M
