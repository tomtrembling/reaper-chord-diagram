--- REAPER's own message box.
---
--- Input is the ImGui window's job as of slice 006. What is left here is the
--- refusal: a message the user can act on, shown when the action will not run
--- or a write failed. It stays native deliberately — a dependency that is
--- missing or an item that is wrong must be reportable without needing the
--- window that may be the thing that is broken.
---
--- The native INPUT dialog this module used to carry is gone. It could not hold
--- a comma-separated chord (REAPER returns the fields comma-separated), and
--- nothing wants it back now that the grid exists.
local M = {}

--- Tell the user something went wrong, in terms they can act on.
--- @param title string
--- @param message string
function M.alert(title, message)
  reaper.ShowMessageBox(message, title, 0)
end

return M
