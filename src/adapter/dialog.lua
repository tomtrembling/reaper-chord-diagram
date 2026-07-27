--- REAPER's own dialogs.
---
--- The native input dialog is a stand-in for the ImGui window that arrives in
--- slice 006. Keeping it behind this interface means the logic chain below it
--- does not change when the real UI replaces it.
local M = {}

--- Ask the user for a set of values on one line each.
--- @param title string
--- @param labels string[]
--- @param defaults string[]
--- @return string[]|nil values, nil if the user cancelled
function M.prompt(title, labels, defaults)
  local ok, csv = reaper.GetUserInputs(title, #labels,
    table.concat(labels, ",") .. ",extrawidth=180", table.concat(defaults, ","))
  if not ok then
    return nil
  end

  -- REAPER returns the fields comma-separated, so a comma typed into the last
  -- field arrives as an extra one. Rejoining the surplus keeps a chord name
  -- like "C, second inversion" intact instead of silently truncating it.
  local values = {}
  for value in (csv .. ","):gmatch("([^,]*),") do
    values[#values + 1] = value
  end
  while #values > #labels do
    values[#labels] = values[#labels] .. "," .. table.remove(values, #labels + 1)
  end
  for i = 1, #labels do
    values[i] = values[i] or ""
  end
  return values
end

--- Tell the user something went wrong, in terms they can act on.
--- @param title string
--- @param message string
function M.alert(title, message)
  reaper.ShowMessageBox(message, title, 0)
end

return M
