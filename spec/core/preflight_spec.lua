local preflight = require("core.preflight")
local version = require("core.version")

--- A machine where everything is as it should be, with one fact replaced.
---
--- Every test below changes ONE thing about a working environment, so what the
--- test is about is the line that differs rather than the six that do not.
local function environment(overrides)
  local env = {
    host = "7.09",
    missing = {},
    unusable = nil,
    projectSaved = true,
    selected = 1,
    empty = 1,
  }
  for key, value in pairs(overrides or {}) do
    env[key] = value
  end
  return env
end

describe("preflight", function()
  it("lets the action run when one empty item is selected on a working install", function()
    assert.is_nil(preflight.refusal(environment()))
  end)

  it("says what is needed when nothing is selected", function()
    local said = preflight.refusal(environment({ selected = 0, empty = 0 }))
    assert.matches("empty item", said)
  end)

  it("refuses to pick one when several items are selected, and says how many", function()
    local said = preflight.refusal(environment({ selected = 3, empty = 3 }))
    assert.matches("3", said)
    assert.matches("one", said)
  end)

  it("will not touch an item that is not an empty item", function()
    local said = preflight.refusal(environment({ selected = 1, empty = 0 }))
    assert.matches("not an empty item", said)
  end)

  it("counts the selection before judging it, when several items are wrong", function()
    -- The entry script used to ask "is any of these empty?" first, so two audio
    -- items answered "that is not an empty item" — true, but not the thing to
    -- fix. A guard on the ORDER of the two questions rather than on either.
    local said = preflight.refusal(environment({ selected = 2, empty = 0 }))
    assert.matches("exactly one", said)
  end)

  it("names the extension that is missing", function()
    local said = preflight.refusal(environment({ missing = { "ReaImGui" } }))
    assert.matches("ReaImGui", said)
  end)

  it("names every missing extension rather than lumping them together", function()
    local said = preflight.refusal(environment({
      missing = { "js_ReaScriptAPI", "ReaImGui" },
    }))
    assert.matches("js_ReaScriptAPI", said)
    assert.matches("ReaImGui", said)
  end)

  it("names the call an installed but too-old extension does not provide", function()
    local said = preflight.refusal(environment({
      unusable = { extension = "js_ReaScriptAPI", call = "JS_LICE_WritePNG" },
    }))
    assert.matches("js_ReaScriptAPI", said)
    assert.matches("JS_LICE_WritePNG", said)
  end)

  it("says which REAPER the plugin needs when the host is older than that", function()
    local said = preflight.refusal(environment({ host = "6.10" }))
    assert.matches("REAPER", said)
    assert.matches(version.MIN_REAPER, said, nil, true)
    assert.matches("6.10", said, nil, true)
  end)

  it("runs anyway on a host that will not say its version", function()
    -- A reporting gap must not become a plugin that refuses to start.
    assert.is_nil(preflight.refusal(environment({ host = nil })))
  end)

  it("blames the host, not the extension, when both would be a problem", function()
    local said = preflight.refusal(environment({
      host = "6.10",
      missing = { "ReaImGui" },
    }))
    assert.matches("REAPER 6.10", said, nil, true)
  end)

  it("asks for the project to be saved before there is anywhere to put an image", function()
    local said = preflight.refusal(environment({ projectSaved = false }))
    assert.matches("Save the project", said)
  end)
end)

describe("preflight for the project-wide sweep", function()
  it("runs with nothing selected at all", function()
    -- The sweep is about every item in the project, so what happens to be
    -- selected is not its business. This is the whole reason it asks a
    -- different question rather than reusing the editor's.
    assert.is_nil(preflight.sweepRefusal(environment({ selected = 0, empty = 0 })))
  end)

  it("still needs somewhere to write the images it rebuilds", function()
    -- Regenerating into a project that was never saved would put the diagrams
    -- nowhere and link them from nothing.
    local said = preflight.sweepRefusal(environment({ projectSaved = false }))
    assert.matches("Save the project", said)
  end)

  it("still needs the extension that does the rendering", function()
    local said = preflight.sweepRefusal(environment({ missing = { "js_ReaScriptAPI" } }))
    assert.matches("js_ReaScriptAPI", said)
  end)
end)
