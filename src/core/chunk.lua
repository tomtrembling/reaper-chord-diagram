--- Item state chunk transformation: text in, text out.
---
--- REAPER hands a whole item to a script as one string and takes it back the
--- same way, so every write risks corrupting fields the plugin has no business
--- touching. Keeping the transformation here — pure, with no REAPER API in
--- sight — is what makes the project's highest-consequence code testable.
---
--- Two facts about the format, both established the hard way in slice 002:
---
---   * `IMGRESOURCEFLAGS` is ignored unless the item also has a NON-EMPTY
---     `<NOTES>` block. The flags line on its own does nothing.
---   * The image fields go in immediately before the chunk's own closing `>`,
---     after any nested sub-chunks.
local voicingOf = require("core.voicing")

local M = {}

--- The chunk line the voicing is stored on.
---
--- The data lives in the state chunk rather than anywhere keyed by item
--- identity, so duplicating an item carries its chord for free.
M.FIELD = "CHORDDIAGRAM"

--- Render note text as REAPER stores it: one `|`-prefixed line each.
--- @param notes string
--- @return string
local function notesBlock(notes)
  local lines = {}
  for line in (tostring(notes):gsub("\r\n?", "\n")):gmatch("[^\n]*") do
    lines[#lines + 1] = "|" .. line
  end
  return "<NOTES\n" .. table.concat(lines, "\n") .. "\n>"
end

--- Remove any image fields and notes this item already carries, so that a
--- second write replaces them rather than stacking a duplicate set.
--- @param text string
--- @return string
local function stripped(text)
  text = text:gsub("\nRESOURCEFN [^\n]*", "")
  text = text:gsub("\nIMGRESOURCEFLAGS [^\n]*", "")
  text = text:gsub("\n<NOTES\n.-\n>", "")
  return text
end

--- Put `block` inside the item, immediately before its own closing `>`.
---
--- Substituted through a function so that a `%` anywhere in the block — a note
--- reading "100% sure", a percent-escaped chord name — is taken literally
--- rather than read as a gsub capture reference.
--- @param text string
--- @param block string
--- @return string|nil chunk
--- @return string|nil err
local function insertedBeforeClose(text, block)
  local out, replacements = text:gsub("\n>%s*$", function() return block .. "\n>\n" end)
  if replacements == 0 then
    return nil, "This does not look like an item state chunk: no closing '>' found."
  end
  return out
end

--- Attach an image to an item.
---
--- `notes` must be non-empty: REAPER ignores the display flags otherwise, and
--- silently producing an item that shows nothing is worse than refusing.
---
--- Any voicing the item carries is left alone, so replacing the image never
--- costs the data the image was made from.
--- @param text string the item's state chunk
--- @param image { filename: string, flags: integer, notes: string }
--- @return string|nil chunk
--- @return string|nil err
function M.setImage(text, image)
  if not image.notes or image.notes == "" then
    return nil, "An item needs non-empty notes, or REAPER ignores the image display flags."
  end

  local block = string.format('\n%s\nRESOURCEFN "%s"\nIMGRESOURCEFLAGS %d',
    notesBlock(image.notes), image.filename, image.flags)
  return insertedBeforeClose(stripped(text), block)
end

--- Store the voicing on the item, replacing any voicing already there.
---
--- The image fields are left alone, so the two writes compose in either order.
--- @param text string the item's state chunk
--- @param v Voicing
--- @return string|nil chunk
--- @return string|nil err
function M.setVoicing(text, v)
  local without = text:gsub("\n" .. M.FIELD .. " [^\n]*", "")
  return insertedBeforeClose(without, "\n" .. M.FIELD .. " " .. voicingOf.encode(v))
end

--- The voicing stored on the item, or nil if it carries no chord.
--- @param text string the item's state chunk
--- @return Voicing|nil
--- @return string|nil err
function M.readVoicing(text)
  local stored = text:match("\n" .. M.FIELD .. " ([^\n]*)")
  if not stored then
    return nil
  end
  return voicingOf.decode(stored)
end

return M
