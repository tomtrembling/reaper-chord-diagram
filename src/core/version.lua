--- Version strings and comparison.
---
--- Used for the plugin's own version (ReaPack metadata) and for checking that
--- the host and required extensions are new enough.
local M = {}

--- The plugin's version.
M.CURRENT = "0.1.0"

--- Split a version string into its numeric components.
--- @param s string
--- @return integer[]
local function components(s)
  local parts = {}
  for n in tostring(s):gmatch("%d+") do
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
