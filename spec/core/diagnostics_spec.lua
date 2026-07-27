local diagnostics = require("core.diagnostics")

describe("the diagnostic report", function()
  it("names each component and the version of it that is installed", function()
    local text = diagnostics.report({
      components = {
        { name = "Chord Diagram", version = "0.12.0" },
        { name = "REAPER", version = "7.09/OSX64", minimum = "6.44" },
      },
    })
    assert.matches("Chord Diagram", text, nil, true)
    assert.matches("0.12.0", text, nil, true)
    assert.matches("7.09/OSX64", text, nil, true)
  end)

  it("says a component is not installed rather than leaving its line blank", function()
    local text = diagnostics.report({
      components = { { name = "ReaImGui", version = nil, minimum = "0.9" } },
    })
    assert.matches("ReaImGui", text, nil, true)
    assert.matches("NOT INSTALLED", text, nil, true)
  end)

  it("flags a version that is below the minimum, next to the minimum", function()
    local text = diagnostics.report({
      components = { { name = "REAPER", version = "6.10", minimum = "6.44" } },
    })
    assert.matches("TOO OLD", text, nil, true)
    assert.matches("6.44", text, nil, true)
  end)

  it("carries the last error, so a report is about something", function()
    local text = diagnostics.report({
      components = {},
      lastError = "2026-07-27 11:04:22  That is not an empty item.",
    })
    assert.matches("That is not an empty item.", text, nil, true)
    assert.matches("2026-07-27 11:04:22", text, nil, true)
  end)

  it("says so when no error has been recorded, rather than trailing off", function()
    local text = diagnostics.report({ components = {} })
    assert.matches("Last error", text, nil, true)
    assert.matches("none recorded", text, nil, true)
  end)

  it("reports resolved paths under their labels", function()
    local text = diagnostics.report({
      components = {},
      paths = { { label = "Project", value = "/Users/tom/Music/Song" } },
    })
    assert.matches("Project", text, nil, true)
    assert.matches("/Users/tom/Music/Song", text, nil, true)
  end)

  it("says a path is unknown rather than reporting an empty one", function()
    -- An empty value reads as a path that IS empty. The distinction between
    -- "nowhere" and "not asked" is the whole point of a diagnostic.
    local text = diagnostics.report({
      components = {},
      paths = { { label = "Project", value = nil } },
    })
    assert.matches("Project%s+unknown", text)
  end)

  it("is plain text a person can paste into a message", function()
    -- The report's destination is a chat window, so anything that is not a
    -- printable character or a line break is a thing that will arrive mangled.
    local text = diagnostics.report({
      components = { { name = "REAPER", version = "7.09/OSX64", minimum = "6.44" } },
      paths = { { label = "Project", value = "C:\\Users\\tom\\Song" } },
      state = { { label = "Items selected", value = "2" } },
      lastError = diagnostics.oneLine("Two lines\nof trouble"),
    })
    -- Tabs are included in what this rejects on purpose: they are re-flowed by
    -- every chat client differently, and the report lines its values up with
    -- spaces precisely so it survives being quoted.
    assert.is_nil(text:find("[^\n\32-\126]"),
      "the report contains something that is neither printable nor a newline")
  end)
end)

describe("a message on its way into stored state", function()
  it("comes back as one line, whatever it was", function()
    local flat = diagnostics.oneLine("Two problems:\nthe first\nand the second")
    assert.are.equal("Two problems: the first and the second", flat)
  end)

  it("survives being handed something that is not a string", function()
    assert.are.equal("nil", diagnostics.oneLine(nil))
    assert.are.equal("42", diagnostics.oneLine(42))
  end)

  it("is capped, so a stack trace cannot bloat what stores it", function()
    local long = diagnostics.oneLine(string.rep("x", 2000))
    assert.is_true(#long < 600, "expected a cap, got " .. #long .. " characters")
    assert.matches("x", long, nil, true)
  end)
end)
