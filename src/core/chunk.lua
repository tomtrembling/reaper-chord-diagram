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
local M = {}

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

--- Attach an image to an item.
---
--- `notes` must be non-empty: REAPER ignores the display flags otherwise, and
--- silently producing an item that shows nothing is worse than refusing.
--- @param text string the item's state chunk
--- @param image { filename: string, flags: integer, notes: string }
--- @return string|nil chunk
--- @return string|nil err
function M.setImage(text, image)
  if not image.notes or image.notes == "" then
    return nil, "An item needs non-empty notes, or REAPER ignores the image display flags."
  end

  local block = string.format('\n%s\nRESOURCEFN "%s"\nIMGRESOURCEFLAGS %d\n>\n',
    notesBlock(image.notes), image.filename, image.flags)

  -- Replaced through a function so that a `%` in the note text or filename is
  -- taken literally rather than read as a gsub capture reference.
  local out, replacements = stripped(text):gsub("\n>%s*$", function() return block end)
  if replacements == 0 then
    return nil, "This does not look like an item state chunk: no closing '>' found."
  end
  return out
end

return M
