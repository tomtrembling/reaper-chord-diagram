--- Reading and writing media items, and the undo block around a write.
---
--- The chunk transformation itself lives in `core.chunk`; this module only
--- carries text to and from REAPER. The stored voicing is likewise carried as
--- opaque text: `core.voicing` owns what that text means.
local M = {}

--- The key the voicing is stored under in the item's extended state.
---
--- REAPER's own documented per-item extended state, reached through
--- `GetSetMediaItemInfo_String` with a `P_EXT:` parameter name. It is saved with
--- the project by design and travels with a duplicated item.
---
--- Slice 005 wrote a bespoke `CHORDDIAGRAM` line into the state chunk instead,
--- which relied on REAPER preserving a line it does not recognise when it
--- reserialises the item from its own model. That was a gamble with the user's
--- data and this reverses it. The ENCODED STRING is byte-for-byte the same; only
--- where it lives changed.
M.VOICING_KEY = "P_EXT:chorddiagram"

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
---
--- ORDER MATTERS. This replaces the item WHOLESALE from text that was captured
--- earlier, and REAPER serialises extended state into that same chunk. So a
--- `M.setStoredVoicing` that runs BEFORE this call is undone by it: the chunk
--- being written back was read before the voicing was stored and still carries
--- the old value. Chunk first, extended state second, always. A later slice that
--- reorders these two for tidiness silently loses every edit to the chord.
--- @param item userdata
--- @param text string
--- @return boolean
function M.setChunk(item, text)
  return reaper.SetItemStateChunk(item, text, false) and true or false
end

--- The encoded voicing the item carries, or nil if it carries no chord.
---
--- An item that has never held a chord answers with an empty string rather than
--- failing, so "no chord here" and "REAPER said no" both arrive as nil and the
--- caller treats a fresh item as blank rather than broken.
--- @param item userdata
--- @return string|nil encoded
function M.storedVoicing(item)
  local ok, text = reaper.GetSetMediaItemInfo_String(item, M.VOICING_KEY, "", false)
  if not ok or text == nil or text == "" then
    return nil
  end
  return text
end

--- Store the encoded voicing on the item.
---
--- ORDER MATTERS: this must run AFTER any `M.setChunk` in the same edit. See the
--- note on `M.setChunk`.
--- @param item userdata
--- @param encoded string
--- @return boolean
function M.setStoredVoicing(item, encoded)
  return reaper.GetSetMediaItemInfo_String(item, M.VOICING_KEY, encoded, true) and true or false
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
