--- The diagnostic report: facts in, plain text out.
---
--- The developer works on macOS and the tester on Windows, so a failure on the
--- tester's machine cannot be reproduced here. This text is how it becomes
--- something actionable instead of "it didn't work", which makes its FORMAT
--- part of the product: it is pasted into a message, read by a person, and has
--- to survive being quoted, wrapped and reflowed. Hence plain text, one fact
--- per line, no tables and no characters that need an encoding.
---
--- Pure, so what the report says is specced rather than hand-checked in REAPER.
--- Gathering the facts is `adapter`'s job; saying what they look like is this.
local version = require("core.version")

local M = {}

--- @class Component something with a version worth reporting
--- @field name string
--- @field version string|nil nil means it is not installed
--- @field minimum string|nil the oldest version the plugin supports
--- @field note string|nil anything else worth one line

--- @class Fact a labelled value — a path, a count, a resolved setting
--- @field label string
--- @field value string|nil

--- @class Facts
--- @field components Component[]
--- @field paths Fact[]|nil
--- @field state Fact[]|nil
--- @field lastError string|nil

--- Width the labels are padded to, so the values line up down the page.
local LABEL = 18

--- @param label string
--- @param value string
local function line(label, value)
  return string.format("%-" .. LABEL .. "s %s", label, value)
end

--- @param c Component
local function componentLine(c)
  if not c.version then
    return line(c.name, "NOT INSTALLED"
      .. (c.minimum and (" (needs " .. c.minimum .. " or newer)") or ""))
  end

  local text = c.version
  if c.minimum and not version.atLeast(c.version, c.minimum) then
    text = text .. " -- TOO OLD, needs " .. c.minimum .. " or newer"
  end
  if c.note then
    text = text .. " (" .. c.note .. ")"
  end
  return line(c.name, text)
end

--- The longest a recorded message may be.
---
--- Generous for a sentence, and short enough that a Lua traceback cannot turn
--- REAPER's extended-state file into something worth noticing.
local CAP = 500

--- One line of printable text, whatever came in.
---
--- The last error is kept in REAPER's persistent extended state, which is an
--- ini file: a newline in a value ends the entry and takes the rest of the
--- file's parsing with it. So flattening is not tidiness, it is the thing that
--- keeps the recorder from being able to break anything.
---
--- Anything at all may be passed — an error object, a nil from a failed call —
--- because the caller is code that is ALREADY going wrong and must not be given
--- a second way to fail.
--- @param message any
--- @return string
function M.oneLine(message)
  local text = tostring(message):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  if #text > CAP then
    text = text:sub(1, CAP) .. "..."
  end
  return text
end

--- @param facts Fact[]|nil
--- @param out string[]
local function factLines(facts, out)
  for _, f in ipairs(facts or {}) do
    out[#out + 1] = line(f.label, f.value or "unknown")
  end
end

--- The report, ready to paste into a message.
---
--- Sections always appear, in this order, whether or not there is anything in
--- them: a heading with nothing under it says "this was checked and there was
--- nothing", where an absent heading says nothing at all — and the reader is
--- someone trying to work out what was not reported.
--- @param facts Facts
--- @return string
function M.report(facts)
  local out = { "Chord Diagram diagnostics", "" }

  out[#out + 1] = "Versions"
  for _, c in ipairs(facts.components or {}) do
    out[#out + 1] = componentLine(c)
  end

  out[#out + 1] = ""
  out[#out + 1] = "Paths"
  factLines(facts.paths, out)

  out[#out + 1] = ""
  out[#out + 1] = "State"
  factLines(facts.state, out)

  out[#out + 1] = ""
  out[#out + 1] = "Last error"
  out[#out + 1] = facts.lastError or "none recorded"

  return table.concat(out, "\n") .. "\n"
end

return M
