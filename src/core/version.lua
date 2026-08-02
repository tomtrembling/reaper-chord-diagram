--- Version strings and comparison.
---
--- Used for the plugin's own version (ReaPack metadata) and for checking that
--- the host and required extensions are new enough.
local M = {}

--- The plugin's version.
---
--- MUST equal the `@version` in the header of every action script under
--- `Chord Diagram/`. That is not a convention anybody has to remember: it is
--- asserted by `spec/header_version_spec.lua`, so bumping one and forgetting
--- the other fails `make test` rather than shipping a diagnostic report that
--- names the wrong version.
M.CURRENT = "0.16.0"

--- The ReaImGui API version the window is written against.
---
--- A REAL FLOOR, not a guess. ReaImGui changed how a script reaches it at 0.9:
--- the versioned Lua shim arrived there, and `adapter.imgui` asks for it by
--- name. The shim exists precisely so a script can name an OLDER API and keep
--- working on newer installs, so naming the version that introduced the shim
--- asks for the widest set of installs that can answer at all. Raising this
--- buys nothing until a call in `adapter.imgui` needs it.
---
--- `adapter.imgui` reads this rather than carrying its own copy: the number the
--- diagnostics report prints as the minimum and the number the shim is actually
--- asked for must be the same number, or the report is fiction.
---
--- CONFIRMED ON A RUNNING INSTALL, at last: the first tester pass, against
--- 0.15.0 on REAPER 7.78/x64, reported `ReaImGui 0.10.0.5 (versioned binding,
--- API 0.9 requested, Dear ImGui 1.92.1)` and js_ReaScriptAPI 1.310. A 0.10
--- install honoured a request for the 0.9 API through the versioned shim, which
--- is exactly the behaviour this floor was chosen on the strength of and which
--- until then had only been read about. Leave the number alone.
M.MIN_REAIMGUI = "0.9"

--- The oldest REAPER the plugin claims to run on.
---
--- INHERITED FROM THE EXTENSION FLOOR RATHER THAN INVENTED. ReaImGui states its
--- own host requirement as REAPER 6.44 or newer, and the window is not optional
--- — so a host below that cannot run this plugin whatever the plugin does about
--- it, and naming REAPER is more actionable than sending the user to install an
--- extension their REAPER will refuse.
---
--- Everything else the plugin uses sits well below this: `RecursiveCreateDirectory`,
--- `GetSetMediaItemInfo_String` with `P_EXT:`, and the LICE calls the spike
--- proved are all older. So this number tracks ReaImGui and nothing else, and
--- moves only when `M.MIN_REAIMGUI` does.
---
--- UNCONFIRMED FROM A RUNNING REAPER — see the slice 009 HITL queue. If it is
--- wrong it is wrong by being too high, which would refuse an install that
--- works; that is the failure worth watching for.
M.MIN_REAPER = "6.44"

--- Split a version string into its numeric components.
---
--- Only the LEADING run of digits and dots is read. REAPER answers "7.09/OSX64"
--- when asked its version, and the 64 in the platform is not a version
--- component: counting it would make 6.44/OSX64 look newer than 6.44.1.
--- @param s string
--- @return integer[]
local function components(s)
  local parts = {}
  for n in (tostring(s):match("^%s*([%d%.]+)") or ""):gmatch("%d+") do
    parts[#parts + 1] = tonumber(n)
  end
  return parts
end

--- Is `actual` at least `minimum`?
---
--- Components are compared one at a time as integers, so 6.10 is correctly
--- treated as later than 6.9. A missing component counts as zero, making
--- "7" and "7.0" equivalent.
--- @param actual string
--- @param minimum string
--- @return boolean
function M.atLeast(actual, minimum)
  local a, b = components(actual), components(minimum)
  for i = 1, math.max(#a, #b) do
    local x, y = a[i] or 0, b[i] or 0
    if x ~= y then
      return x > y
    end
  end
  return true
end

return M
