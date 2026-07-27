local layout = require("core.layout")
local voicing = require("core.voicing")

--- Every primitive playing a given part in the diagram.
local function withRole(computed, role)
  local found = {}
  for _, p in ipairs(computed.primitives) do
    if p.role == role then
      found[#found + 1] = p
    end
  end
  return found
end

--- The horizontal centre of a primitive, whatever kind it is.
local function centreX(p)
  return p.cx or (p.x1 + p.x2) / 2
end

--- The set of string positions carrying a marker of the given role.
local function markedStrings(computed, role)
  local strings = withRole(computed, "string")
  local marked = {}
  for _, p in ipairs(withRole(computed, role)) do
    for i, s in ipairs(strings) do
      if math.abs(centreX(p) - s.x1) < 1e-9 then marked[i] = true end
    end
  end
  return marked
end

describe("layout", function()
  local C = assert(voicing.parse("x32010", "C"))

  it("draws a nut for an open-position chord", function()
    assert.are.equal(1, #withRole(layout.compute(C, 1024, 1024), "nut"))
  end)

  it("draws one line per string and one per fret of the span", function()
    local computed = layout.compute(C, 1024, 1024)
    assert.are.equal(6, #withRole(computed, "string"))
    assert.are.equal(5, #withRole(computed, "fret"))
  end)

  it("spaces the strings evenly across the grid, low E on the left", function()
    local strings = withRole(layout.compute(C, 1024, 1024), "string")
    local gap = strings[2].x1 - strings[1].x1
    for i = 2, #strings do
      assert.is_true(strings[i].x1 > strings[i - 1].x1)
      assert.is_true(math.abs((strings[i].x1 - strings[i - 1].x1) - gap) < 1e-9)
    end
  end)

  it("draws one dot per fretted string", function()
    -- x32010 frets the A, D and B strings; the others are muted or open.
    assert.are.equal(3, #withRole(layout.compute(C, 1024, 1024), "dot"))
  end)

  it("places a dot on its own string, between the fret lines that bracket it", function()
    local computed = layout.compute(C, 1024, 1024)
    local strings = withRole(computed, "string")
    local frets = withRole(computed, "fret")
    local dots = withRole(computed, "dot")

    -- The A string is fretted at the third fret.
    local dot
    for _, d in ipairs(dots) do
      if math.abs(d.cx - strings[2].x1) < 1e-9 then dot = d end
    end
    assert.is_table(dot)
    assert.is_true(dot.cy > frets[2].y1)
    assert.is_true(dot.cy < frets[3].y1)
  end)

  it("places a dot relative to the top of the window, not the nut", function()
    -- Framed from the seventh fret, so the ninth fret is the third cell down.
    local high = assert(voicing.parse("x79987", "B"))
    local computed = layout.compute(high, 1024, 1024)
    local frets = withRole(computed, "fret")
    local strings = withRole(computed, "string")

    local dot
    for _, d in ipairs(withRole(computed, "dot")) do
      if math.abs(d.cx - strings[3].x1) < 1e-9 then dot = d end
    end
    assert.is_table(dot)
    assert.is_true(dot.cy > frets[2].y1)
    assert.is_true(dot.cy < frets[3].y1)
  end)

  it("marks the open and muted strings, and only those", function()
    local computed = layout.compute(C, 1024, 1024)
    assert.are.same({ [4] = true, [6] = true }, markedStrings(computed, "open"))
    assert.are.same({ [1] = true }, markedStrings(computed, "muted"))
  end)

  it("puts the open and muted markers above the nut", function()
    local computed = layout.compute(C, 1024, 1024)
    local nutY = withRole(computed, "nut")[1].y1
    for _, role in ipairs({ "open", "muted" }) do
      for _, p in ipairs(withRole(computed, role)) do
        local bottom = p.cy and (p.cy + p.r) or math.max(p.y1, p.y2)
        assert.is_true(bottom < nutY)
      end
    end
  end)

  it("renders the chord name as a title, clear of the markers below it", function()
    local computed = layout.compute(C, 1024, 1024)
    local title = withRole(computed, "title")[1]
    assert.are.equal("C", title.text)

    local highestMarker = math.huge
    for _, role in ipairs({ "open", "muted" }) do
      for _, p in ipairs(withRole(computed, role)) do
        highestMarker = math.min(highestMarker, p.cy and (p.cy - p.r) or math.min(p.y1, p.y2))
      end
    end
    assert.is_true(title.y + title.h <= highestMarker)
  end)

  it("draws no title when the chord has no name", function()
    local unnamed = assert(voicing.parse("x32010"))
    assert.are.equal(0, #withRole(layout.compute(unnamed, 1024, 1024), "title"))
  end)

  it("emits only backend-neutral primitives, in normalised coordinates", function()
    local kinds = { line = true, rect = true, circle = true, text = true }
    for _, p in ipairs(layout.compute(C, 1024, 1024).primitives) do
      assert.is_true(kinds[p.kind], "unknown primitive kind: " .. tostring(p.kind))
      for _, field in ipairs({ "x", "y", "x1", "y1", "x2", "y2", "cx", "cy" }) do
        if p[field] then
          assert.is_true(p[field] >= 0 and p[field] <= 1,
            string.format("%s.%s = %s is outside the unit square", p.role, field, p[field]))
        end
      end
    end
  end)

  it("scales to any surface without changing the primitives", function()
    local small = layout.compute(C, 128, 128).primitives
    local large = layout.compute(C, 4096, 4096).primitives
    assert.are.same(small, large)
  end)

  describe("hit-testing", function()
    it("maps a dot's own position back to the string and fret it was drawn for", function()
      for s = 1, 6 do
        for fret = 1, 5 do
          local frets = { -1, -1, -1, -1, -1, -1 }
          frets[s] = fret
          local computed = layout.compute(voicing.new({ frets = frets }), 800, 600)
          local dot = withRole(computed, "dot")[1]
          local hitString, hitFret = layout.cellAt(computed, dot.cx * 800, dot.cy * 600)
          assert.are.equal(s, hitString)
          assert.are.equal(fret, hitFret)
        end
      end
    end)

    it("reads the marker row above the nut as the open string", function()
      local computed = layout.compute(C, 1024, 1024)
      local ring = withRole(computed, "open")[1]
      local hitString, hitFret = layout.cellAt(computed, ring.cx * 1024, ring.cy * 1024)
      assert.are.equal(4, hitString)
      assert.are.equal(voicing.OPEN, hitFret)
    end)

    it("reports nothing for a point outside the diagram", function()
      local computed = layout.compute(C, 1024, 1024)
      assert.is_nil(layout.cellAt(computed, 0, 0))
      assert.is_nil(layout.cellAt(computed, 1023, 1023))
    end)
  end)
end)
