--- The ReaPack header and `core.version.CURRENT` must say the same thing.
---
--- They are two declarations of one fact, and they drifted for eight slices:
--- the header reached 0.11.0 while `CURRENT` still said "0.1.0". Nothing read
--- `CURRENT` at the time, so nothing complained — but the diagnostics action
--- reads it now, and a diagnostic report stating the wrong version is worse
--- than one that omits it.
---
--- The header cannot be read at run time from pure Lua, so the relationship is
--- enforced HERE instead: a slice that bumps `@version` and forgets `CURRENT`
--- fails `make test` on the dev machine, before the build reaches the tester.
local version = require("core.version")

--- The directory ReaPack installs actions from.
---
--- Everything in it ships, and only what ships is in it. The slice 002 spike
--- used to sit here too and had to be named as an exception; it now lives in
--- `ref/`, which is what let that exception go. Anything put back here is a
--- shipped action and is checked as one.
local ACTIONS = "Chord Diagram"

--- Every action script ReaPack ships as part of the plugin.
---
--- Listed by asking the filesystem rather than by naming them, so a script
--- added by a later slice is checked without anybody remembering to add it.
local function actionScripts()
  local found = {}
  local ls = io.popen('ls "' .. ACTIONS .. '"')
  if not ls then
    return found
  end
  for name in ls:lines() do
    if name:match("%.lua$") then
      found[#found + 1] = ACTIONS .. "/" .. name
    end
  end
  ls:close()
  return found
end

--- @param path string
--- @return string|nil
local function headerVersion(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("a")
  file:close()
  return text:match("@version%s+([%d%.]+)")
end

describe("the shipped action scripts", function()
  it("declare the version the plugin says it is", function()
    local scripts = actionScripts()
    assert.is_true(#scripts > 0, "no action scripts found in " .. ACTIONS)

    for _, path in ipairs(scripts) do
      assert.are.equal(version.CURRENT, headerVersion(path),
        path .. " @version disagrees with core.version.CURRENT")
    end
  end)
end)
