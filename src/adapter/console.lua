--- Console output.
---
--- Adapter modules are the only place REAPER's API may be touched; see
--- .luacheckrc, which declares the `reaper` global for this directory alone.
local M = {}

--- Write a line to REAPER's console.
--- @param message string
function M.log(message)
  reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

return M
