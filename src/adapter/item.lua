--- Reading and writing media items, and the undo block around a write.
---
--- The chunk transformation itself lives in `core.chunk`; this module only
--- carries text to and from REAPER.
local M = {}

--- The selected items that are empty items — no takes.
---
--- The action refuses to run on anything else, so an audio or MIDI item is
--- never altered by accident.
--- @return table[] items
--- @return integer selected total number of items selected, empty or not
function M.selectedEmptyItems()
  local empty = {}
  local total = reaper.CountSelectedMediaItems(0)
  for i = 0, total - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if reaper.CountTakes(item) == 0 then
      empty[#empty + 1] = item
    end
  end
  return empty, total
end

--- The item's state chunk.
--- @param item userdata
--- @return string|nil
function M.chunk(item)
  local ok, text = reaper.GetItemStateChunk(item, "", false)
  if not ok then
    return nil
  end
  return text
end

--- Replace the item's state chunk.
--- @param item userdata
--- @param text string
--- @return boolean
function M.setChunk(item, text)
  return reaper.SetItemStateChunk(item, text, false) and true or false
end

--- Run `fn` as one undoable edit, so a chord behaves like any other REAPER
--- edit under Ctrl+Z.
--- @param label string
--- @param fn fun(): boolean, string|nil
--- @return boolean ok
--- @return string|nil err
function M.asUndoableEdit(label, fn)
  reaper.Undo_BeginBlock()
  local ok, err = fn()
  reaper.Undo_EndBlock(label, -1)
  reaper.UpdateArrange()
  return ok, err
end

return M
