--- The last thing that went wrong, remembered across script runs.
---
--- "Copies the last error to the clipboard" needs something to have recorded
--- one, and the thing that records it lives in a DIFFERENT script from the one
--- that reports it: the action fails, the user then runs the diagnostic action,
--- and that is a separate ReaScript with none of the first one's state. So the
--- message goes into REAPER's extended state, which is process-wide and, asked
--- to persist, survives a restart as well.
---
--- THIS MODULE MUST NOT BE ABLE TO FAIL. It is called from the paths where
--- something has already gone wrong, and a diagnostics tool that throws is
--- worse than none at all: it would turn a message the user could act on into a
--- script error they cannot. Every REAPER call here is therefore wrapped, the
--- message is flattened by `core.diagnostics` before it is stored, and nothing
--- reports whether recording worked — there would be nowhere to report it to.
local diagnostics = require("core.diagnostics")

local M = {}

--- Where the value lives. Named for the plugin, so it is findable by hand in
--- REAPER's `reaper-extstate.ini` if it ever comes to that.
M.SECTION = "chorddiagram"
M.KEY = "lasterror"

--- Remember that this went wrong.
---
--- Timestamped, because a report whose "last error" is three weeks old and a
--- report about what just happened are otherwise the same text, and the person
--- reading it cannot tell which they have.
---
--- NOTHING CLEARS THIS ON SUCCESS, deliberately. An intermittent failure the
--- user worked around on the second try is exactly the one worth reporting, and
--- clearing on success would erase it. The timestamp is what says whether the
--- error is the one being described.
--- @param message any
function M.record(message)
  pcall(function()
    local stamp = os.date("%Y-%m-%d %H:%M:%S")
    reaper.SetExtState(M.SECTION, M.KEY,
      stamp .. "  " .. diagnostics.oneLine(message), true)
  end)
end

--- The last recorded error, or nil if nothing has gone wrong yet.
--- @return string|nil
function M.last()
  local ok, text = pcall(reaper.GetExtState, M.SECTION, M.KEY)
  if not ok or text == nil or text == "" then
    return nil
  end
  return text
end

return M
