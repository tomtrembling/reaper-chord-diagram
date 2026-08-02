-- @noindex
--
-- Capture an item's state chunk, for the chunk fixtures in
-- spec/fixtures/item_chunks.lua.
--
-- This is a development tool, not part of the plugin. It is a FILE rather than
-- a snippet to paste because the snippet it replaces arrived at the tester as
-- "unexpected symbol near" -- copying Lua out of a chat window turns straight
-- quotes into curly ones and can prepend an invisible byte-order mark, neither
-- of which Lua will parse.
--
-- HOW TO USE
--   Put this file in REAPER's Scripts folder (Options > Show REAPER resource
--   path), then Actions > Show action list > New action > Load ReaScript, and
--   pick it. Select ONE item and run it. The chunk appears in the console --
--   select all of it and send it back.
--
--   Wanted, one run each: an EMPTY item, an item ALREADY CARRYING a chord
--   diagram, and an AUDIO item.

local item = reaper.GetSelectedMediaItem(0, 0)

if not item then
  reaper.ShowMessageBox(
    "Select one item first, then run this again.",
    "Nothing selected", 0)
  return
end

local ok, chunk = reaper.GetItemStateChunk(item, "", false)

if not ok then
  reaper.ShowMessageBox(
    "REAPER would not give up this item's chunk. Try another item.",
    "Could not read the item", 0)
  return
end

-- Which kind of item this is decides which fixture the chunk belongs to, and
-- it is not always obvious from the chunk text alone.
local takes = reaper.CountTakes(item)
local kind = takes == 0 and "EMPTY item" or (takes .. " take(s) -- audio or MIDI item")

reaper.ShowConsoleMsg("")
reaper.ShowConsoleMsg("---- BEGIN CHUNK (" .. kind .. ") ----\n")
reaper.ShowConsoleMsg(chunk)
reaper.ShowConsoleMsg("---- END CHUNK ----\n")
