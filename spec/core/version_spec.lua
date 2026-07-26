local version = require("core.version")

describe("version", function()
  it("accepts a version newer than the minimum", function()
    assert.is_true(version.atLeast("6.83", "6.80"))
  end)

  it("compares components numerically, not as decimals", function()
    -- 6.10 is a later release than 6.9, though it is a smaller decimal.
    assert.is_true(version.atLeast("6.10", "6.9"))
  end)

  it("rejects a version older than the minimum", function()
    assert.is_false(version.atLeast("6.80", "6.83"))
  end)

  it("accepts a version equal to the minimum", function()
    assert.is_true(version.atLeast("7.09", "7.09"))
  end)

  it("treats absent components as zero", function()
    assert.is_true(version.atLeast("7", "7.0.0"))
    assert.is_false(version.atLeast("7.0", "7.0.1"))
  end)

  it("reports its own version as a string", function()
    assert.is_string(version.CURRENT)
  end)
end)
