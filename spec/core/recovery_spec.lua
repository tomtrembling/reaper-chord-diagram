local recovery = require("core.recovery")
local voicing = require("core.voicing")

describe("planning what to do with one item", function()
  it("finds no chord on an item that has never carried one", function()
    assert.are.equal(recovery.NONE, recovery.plan(nil).status)
  end)

  it("hands back the chord an item is carrying", function()
    local stored = voicing.encode(voicing.parse("x32010", "C"))

    local plan = recovery.plan(stored)

    assert.are.equal(recovery.CHORD, plan.status)
    assert.are.equal("x32010", voicing.toText(plan.voicing))
    assert.are.equal("C", plan.voicing.name)
  end)

  it("refuses to act on a chord it cannot read, and says why", function()
    -- The sweep writes to every item it repairs, so this is the case that
    -- decides whether a damaged item is left alone or overwritten from a shape
    -- nobody played. It is left alone.
    local plan = recovery.plan("v1;s=6;f=0,2;g=0,0;b=;p=;n=")

    assert.are.equal(recovery.DAMAGED, plan.status)
    assert.is_nil(plan.voicing)
    assert.matches("damaged", plan.reason)
  end)

  it("leaves a chord written by a later version of the plugin alone", function()
    -- A project that came back from someone running a newer build. Rebuilding
    -- its images from rules that no longer describe the data would replace
    -- every diagram in it with a wrong one, in a single undoable step.
    local plan = recovery.plan("v2;s=6;f=-1,3,2,0,1,0;g=0,0,0,0,0,0;b=;p=;n=C")

    assert.are.equal(recovery.DAMAGED, plan.status)
    assert.is_nil(plan.voicing)
  end)
end)

--- A sweep that found nothing wrong, with one number replaced.
local function tally(overrides)
  local counts = { regenerated = 0, intact = 0, damaged = 0, failed = 0 }
  for key, value in pairs(overrides or {}) do
    counts[key] = value
  end
  return counts
end

describe("reporting what the sweep did", function()
  it("says how many diagrams it rebuilt", function()
    assert.matches("5 diagrams", recovery.summary(tally({ regenerated = 5, intact = 7 })))
  end)

  it("still answers when nothing was missing, and says what it checked", function()
    -- "Nothing happened" and "I looked at twelve chords and all twelve images
    -- were there" are the same screen otherwise, and the second is the answer
    -- to "is my diagram folder actually missing?".
    local said = recovery.summary(tally({ intact = 12 }))

    assert.matches("No diagrams needed regenerating", said)
    assert.matches("12", said)
  end)

  it("says the project carries no chords rather than counting to zero twice", function()
    -- Running this on the wrong project, or before any chord has been made.
    -- "Checked 0 chords" is arithmetic; "there are no chords here" is an answer.
    assert.matches("No chords", recovery.summary(tally()))
  end)

  it("says how many chords it would not touch, and that it left them alone", function()
    local said = recovery.summary(tally({ regenerated = 2, damaged = 1 }))

    assert.matches("1 chord", said)
    assert.matches("could not be read", said)
    assert.matches("left alone", said)
  end)

  it("owns up to the diagrams it tried to rebuild and could not", function()
    -- A partial sweep must not read as a complete one. The chords it did fix
    -- stay fixed; the count of the ones it did not is how the user knows to
    -- look at the diagnostics rather than at their project.
    local said = recovery.summary(tally({ regenerated = 2, failed = 3 }))

    assert.matches("3 diagrams could not be rebuilt", said)
  end)
end)
