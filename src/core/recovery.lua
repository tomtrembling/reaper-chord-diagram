--- What the sweep does with one item, and what it says when it has finished.
local voicing = require("core.voicing")

local M = {}

--- The item carries no chord at all.
M.NONE = "none"

--- The item carries a chord that can be read.
M.CHORD = "chord"

--- The item carries something this version cannot read.
M.DAMAGED = "damaged"

--- What to do with the chord data one item carries.
---
--- THE ONLY THREE ANSWERS ARE "nothing here", "here is the chord" and "do not
--- touch this one". There is deliberately no fourth answer that guesses: a
--- voicing that will not decode is a voicing the sweep must leave exactly as it
--- found it, because the alternative is rendering a picture of a shape the user
--- never played over the top of the data that would have said what they did
--- play. The sweep is run precisely when something is already wrong, so its
--- failure mode has to be doing less rather than more.
--- @param stored string|nil the item's encoded voicing
--- @return { status: string, voicing: Voicing|nil, reason: string|nil }
function M.plan(stored)
  if stored == nil or stored == "" then
    return { status = M.NONE }
  end
  local v, err = voicing.decode(stored)
  if not v then
    return { status = M.DAMAGED, reason = err }
  end
  return { status = M.CHORD, voicing = v }
end

--- @class Tally what one sweep found and did
--- @field regenerated integer images that were missing and have been rebuilt
--- @field intact integer chords whose image was already there
--- @field damaged integer chords that could not be read, and were left alone
--- @field failed integer chords whose image could not be rebuilt

--- `n` of something, pluralised.
--- @param n integer
--- @param noun string
--- @return string
local function many(n, noun)
  return n .. " " .. noun .. (n == 1 and "" or "s")
end

--- What the user is told when the sweep finishes.
---
--- THE COUNT IS REPORTED EVEN WHEN IT IS ZERO. This action is run by somebody
--- who thinks their diagrams have gone, so "0 regenerated, 12 images were
--- already there" is not a null result — it is the answer to their question,
--- and it says to go looking somewhere other than the image folder.
--- @param counts Tally
--- @return string
function M.summary(counts)
  local chords = counts.regenerated + counts.intact + counts.damaged + counts.failed
  if chords == 0 then
    return "No chords found in this project.\n\nNothing here carries a chord "
      .. "diagram, so there was nothing to regenerate."
  end

  local out = { counts.regenerated == 0
    and "No diagrams needed regenerating."
    or ("Regenerated " .. many(counts.regenerated, "diagram") .. ".") }

  out[#out + 1] = ""
  out[#out + 1] = "Checked " .. many(chords, "chord") .. " in this project."
  if counts.intact > 0 then
    out[#out + 1] = many(counts.intact, "image")
      .. (counts.intact == 1 and " was" or " were") .. " already there."
  end
  if counts.damaged > 0 then
    out[#out + 1] = many(counts.damaged, "chord")
      .. " could not be read, and " .. (counts.damaged == 1 and "was" or "were")
      .. " left alone."
  end
  if counts.failed > 0 then
    -- Said out loud rather than folded into the regenerated count, so a sweep
    -- that half worked cannot read as one that worked. The diagnostics action
    -- carries the reason; this only has to say that there is one.
    out[#out + 1] = many(counts.failed, "diagram") .. " could not be rebuilt. "
      .. "Run \"Chord Diagram: copy diagnostics\" to see why."
  end

  return table.concat(out, "\n")
end

return M
