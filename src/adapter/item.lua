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

--- Write the chord to the item: the state chunk, then the extended state.
---
--- ORDER MATTERS, AND IT IS NOT ARBITRARY — see the note on `M.setChunk`. The
--- chunk goes first because REAPER serialises extended state into that same
--- chunk, so a chunk captured before the voicing was stored would undo the
--- store on its way in.
---
--- WHICH LEAVES THE QUESTION THIS FUNCTION EXISTS TO ANSWER: what if the SECOND
--- write fails? The first has already landed, so the item would carry the new
--- picture and the old data — the one state the whole design forbids, since the
--- item's data is the source of truth and the PNG is a derivative. A user
--- reopening that item would be shown a chord that is not the one displayed on
--- it, and applying would then overwrite the picture from the stale voicing.
---
--- So the first write is PUT BACK. `original` is the chunk exactly as it was
--- read before the window opened, so restoring it returns the item to the state
--- the user last saw. Both writes are inside one undo block either way, so the
--- rollback is not visible as an edit and there is nothing extra to Ctrl+Z
--- through.
--- @param item userdata
--- @param original string the chunk as it was before this edit
--- @param updated string the chunk to write
--- @param encoded string the voicing to store
--- @return boolean ok
--- @return string|nil err
function M.writeChord(item, original, updated, encoded)
  if not M.setChunk(item, updated) then
    return false, "REAPER refused the updated item state."
  end
  if not M.setStoredVoicing(item, encoded) then
    M.setChunk(item, original)
    return false, "REAPER refused the item's chord data, so the diagram was "
      .. "put back as it was rather than left on an item that no longer "
      .. "carries the voicing that produced it."
  end
  return true
end

--- Run `fn` as one undoable edit, so a chord behaves like any other REAPER
--- edit under Ctrl+Z.
---
--- `fn` IS CALLED INSIDE A pcall so that `Undo_EndBlock` always runs. An error
--- thrown between the two would otherwise leave REAPER with an undo block open
--- for the rest of the session, quietly collecting the user's next edits into
--- a block labelled after a chord — a failure that outlives the action that
--- caused it and does not look like it came from here.
--- @param label string
--- @param fn fun(): boolean, string|nil
--- @return boolean ok
--- @return string|nil err
function M.asUndoableEdit(label, fn)
  reaper.Undo_BeginBlock()
  local completed, ok, err = pcall(fn)
  reaper.Undo_EndBlock(label, -1)
  reaper.UpdateArrange()
  if not completed then
    return false, tostring(ok)
  end
  return ok, err
end

return M
