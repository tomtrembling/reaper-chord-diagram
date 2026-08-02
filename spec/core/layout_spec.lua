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

--- Every horizontal line closing a fret cell, top of the window first. The top
--- one is the nut or a fret depending on the framing, which is exactly what
--- these tests must not have to care about.
local function fretLines(computed)
  local lines = {}
  for _, role in ipairs({ "nut", "fret" }) do
    for _, p in ipairs(withRole(computed, role)) do
      lines[#lines + 1] = p
    end
  end
  table.sort(lines, function(a, b) return a.y1 < b.y1 end)
  return lines
end

--- The dot drawn on a given string, if there is one.
local function dotOn(computed, index)
  local string = withRole(computed, "string")[index]
  for _, d in ipairs(withRole(computed, "dot")) do
    if math.abs(d.cx - string.x1) < 1e-9 then return d end
  end
end

--- Which cell of the window a dot sits in, counting 1 from the top.
local function cellOf(computed, dot)
  local lines = fretLines(computed)
  for cell = 1, #lines - 1 do
    if dot.cy > lines[cell].y1 and dot.cy < lines[cell + 1].y1 then return cell end
  end
end

--- The body of the bar drawn for a barre: the rectangle running from the first
--- string it covers to the last. Its rounded ends are separate primitives
--- playing the same role, so the body is picked out by kind.
local function barreBody(computed)
  for _, p in ipairs(withRole(computed, "barre")) do
    if p.kind == "rect" then return p end
  end
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
  --- A Bm barre shape framed from the seventh fret: no nut in view.
  local Bm = assert(voicing.parse("x79987", "Bm"))

  it("draws a nut for an open-position chord", function()
    assert.are.equal(1, #withRole(layout.compute(C, 1024, 1024), "nut"))
  end)

  it("draws no nut when the window starts above it", function()
    assert.are.equal(0, #withRole(layout.compute(Bm, 1024, 1024), "nut"))
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
    -- The A string of a C is fretted at the third fret, and the nut is in view,
    -- so the dot belongs in the third cell.
    local computed = layout.compute(C, 1024, 1024)
    local dot = dotOn(computed, 2)
    assert.is_table(dot)
    assert.are.equal(3, cellOf(computed, dot))
  end)

  it("places a dot relative to the top of the window, not the nut", function()
    -- Framed from the seventh fret, so the ninth fret is the third cell down —
    -- the same cell the third fret of a C occupies, which is the whole point.
    local computed = layout.compute(Bm, 1024, 1024)
    local dot = dotOn(computed, 3)
    assert.is_table(dot)
    assert.are.equal(3, cellOf(computed, dot))
  end)

  it("puts every dot of a high voicing in the cell its fret number names", function()
    local computed = layout.compute(Bm, 1024, 1024)
    -- x79987, framed from the seventh: cells 1, 3, 3, 2, 1 on strings 2 to 6.
    for index, cell in pairs({ [2] = 1, [3] = 3, [4] = 3, [5] = 2, [6] = 1 }) do
      local dot = dotOn(computed, index)
      assert.is_table(dot)
      assert.are.equal(cell, cellOf(computed, dot), "string " .. index)
    end
  end)

  it("labels a window that starts above the nut with the fret it starts at", function()
    local marker = withRole(layout.compute(Bm, 1024, 1024), "position")
    assert.are.equal(1, #marker)
    assert.are.equal("7fr", marker[1].text)
  end)

  it("states the fret number for a window in the double figures", function()
    local high = assert(voicing.parse("12-14-14-13-12-12", "E"))
    assert.are.equal("12fr", withRole(layout.compute(high, 1024, 1024), "position")[1].text)
  end)

  it("draws no position marker when the nut is in view, because the nut says it", function()
    assert.are.equal(0, #withRole(layout.compute(C, 1024, 1024), "position"))
  end)

  it("puts the marker beside the first cell of the window, clear of the grid", function()
    local computed = layout.compute(Bm, 1024, 1024)
    local marker = withRole(computed, "position")[1]
    local lines = fretLines(computed)
    local leftmostString = withRole(computed, "string")[1]

    assert.is_true(marker.x + marker.w <= leftmostString.x1)

    local middle = marker.y + marker.h / 2
    assert.is_true(middle > lines[1].y1)
    assert.is_true(middle < lines[2].y1)
  end)

  it("keeps the marker off the edge of the image and centred in its gutter", function()
    -- The LICE backend draws from the box's LEFT EDGE, so a box starting at zero
    -- puts the exported marker hard against the edge of the image — a placement
    -- nobody chose. Inset by a stroke at each side it clears the edge, stops
    -- short of the strings, and is centred in the gutter for the backend that
    -- centres. The width is not reduced by the move: `12fr` all but fills it.
    local computed = layout.compute(Bm, 1024, 1024)
    local marker = withRole(computed, "position")[1]
    local gutter = withRole(computed, "string")[1].x1

    assert.are.equal(layout.STROKE, marker.x)
    assert.are.equal(gutter - layout.STROKE * 2, marker.w)
    assert.is_true(math.abs((marker.x + marker.w / 2) - gutter / 2) < 1e-9)
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

  it("still marks a string that rings open under a window above the nut", function()
    -- An open A string beneath a shape at the seventh fret. The ring goes above
    -- the top of the window, where a songbook puts it.
    local computed = layout.compute(assert(voicing.parse("x-0-9-9-7-x", "A")), 1024, 1024)
    assert.are.same({ [2] = true }, markedStrings(computed, "open"))

    local topOfWindow = fretLines(computed)[1].y1
    local ring = withRole(computed, "open")[1]
    assert.is_true(ring.cy + ring.r < topOfWindow)
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

  it("gives the title the grid's own span, so it starts over the low E string", function()
    -- The two edges of a text box that matter, and why this one is the grid:
    -- the LICE backend starts the exported title at the box's LEFT edge, which
    -- is therefore chosen — the low E string, a landmark on the diagram — rather
    -- than left at the edge of the image; and the ImGui backend centres on the
    -- box's CENTRE, which the grid being centred on the canvas leaves exactly
    -- where the old full-width box had it. See the TEXT section of `core.layout`.
    local computed = layout.compute(C, 1024, 1024)
    local title = withRole(computed, "title")[1]
    local strings = withRole(computed, "string")

    assert.are.equal(strings[1].x1, title.x)
    assert.are.equal(strings[#strings].x1, title.x + title.w)
    assert.is_true(math.abs((title.x + title.w / 2) - 0.5) < 1e-9)
  end)

  it("draws no title when the chord has no name", function()
    local unnamed = assert(voicing.parse("x32010"))
    assert.are.equal(0, #withRole(layout.compute(unnamed, 1024, 1024), "title"))
  end)

  it("draws only what the window can hold when a shape is wider than the span", function()
    -- The span is fixed at five, so a shape reaching from the first fret to the
    -- twelfth cannot be shown whole by any framing. It shows what it can rather
    -- than painting a dot off the edge of the diagram.
    local stretched = voicing.new({ frets = { 1, -1, -1, -1, -1, 12 } })
    local computed = layout.compute(stretched, 1024, 1024)
    assert.are.equal(1, #withRole(computed, "dot"))
    for _, p in ipairs(computed.primitives) do
      if p.cy then assert.is_true(p.cy >= 0 and p.cy <= 1) end
    end
  end)

  it("keeps the window five frets deep however the chord is framed", function()
    for _, v in ipairs({ C, Bm }) do
      local computed = layout.compute(v, 1024, 1024)
      local lines = fretLines(computed)
      assert.are.equal(voicing.SPAN + 1, #lines)

      local gap = lines[2].y1 - lines[1].y1
      for i = 2, #lines do
        assert.is_true(math.abs((lines[i].y1 - lines[i - 1].y1) - gap) < 1e-9)
      end
    end
  end)

  it("emits only backend-neutral primitives, in normalised coordinates", function()
    local kinds = { line = true, rect = true, circle = true, text = true }
    local barred = voicing.setBarre(assert(voicing.parse("133211", "F")), 1, 1, 6)
    for _, v in ipairs({ C, Bm, barred }) do
      for _, p in ipairs(layout.compute(v, 1024, 1024).primitives) do
        assert.is_true(kinds[p.kind], "unknown primitive kind: " .. tostring(p.kind))
        for _, field in ipairs({ "x", "y", "x1", "y1", "x2", "y2", "cx", "cy" }) do
          if p[field] then
            assert.is_true(p[field] >= 0 and p[field] <= 1,
              string.format("%s.%s = %s is outside the unit square", p.role, field, p[field]))
          end
        end
      end
    end
  end)

  it("gives every text primitive a box and an alignment to place it in that box",
    function()
      -- `align` is the one field the two backends do not treat alike: the ImGui
      -- backend measures the string and centres it, and the LICE backend cannot
      -- measure text at all and so draws from the top left of the box. A text
      -- primitive that omitted the field would therefore be centred on screen by
      -- accident of the default and never in the PNG, which is a divergence
      -- nobody would think to look for. Stating it is what makes the difference
      -- a known one. See the TEXT section of `core.layout`.
      local unaligned = 0
      for _, v in ipairs({ C, Bm }) do
        for _, p in ipairs(layout.compute(v, 1024, 1024).primitives) do
          if p.kind == "text" then
            unaligned = unaligned + 1
            assert.are.equal("centre", p.align, p.role .. " has no alignment")
            for _, field in ipairs({ "x", "y", "w", "h", "size" }) do
              assert.is_number(p[field], p.role .. " has no " .. field)
            end
          end
        end
      end
      -- A title each, and the position marker the high voicing needs.
      assert.are.equal(3, unaligned)
    end)

  it("scales to any surface without changing the primitives", function()
    local small = layout.compute(C, 128, 128).primitives
    local large = layout.compute(C, 4096, 4096).primitives
    assert.are.same(small, large)
  end)

  describe("barres", function()
    local F = voicing.setBarre(assert(voicing.parse("133211", "F")), 1, 1, 6)

    it("spans every string of a full barre, at the fret it was laid across", function()
      local computed = layout.compute(F, 1024, 1024)
      local strings = withRole(computed, "string")
      local bar = barreBody(computed)

      assert.is_table(bar)
      assert.are.equal(strings[1].x1, bar.x)
      assert.are.equal(strings[6].x1, bar.x + bar.w)
      assert.are.equal(1, cellOf(computed, { cy = bar.y + bar.h / 2 }))
    end)

    it("stops at the last string a partial barre covers", function()
      -- The small F bars the top two strings only. A bar drawn across the whole
      -- neck would claim a finger the guitarist never put there.
      local small = voicing.setBarre(assert(voicing.parse("xx3211", "F")), 1, 5, 6)
      local computed = layout.compute(small, 1024, 1024)
      local strings = withRole(computed, "string")
      local bar = barreBody(computed)

      assert.are.equal(strings[5].x1, bar.x)
      assert.are.equal(strings[6].x1, bar.x + bar.w)
      assert.is_true(bar.x > strings[4].x1)
    end)

    it("puts the bar in the cell of the window, not the cell of the fret number", function()
      -- Slice 004's framing, applied to the bar: a Bm barred at the seventh
      -- fret in a window based at seven belongs in the FIRST cell, level with
      -- the dots on the strings it does not cover.
      local barred = voicing.setBarre(Bm, 7, 2, 6)
      local computed = layout.compute(barred, 1024, 1024)
      local bar = barreBody(computed)

      assert.are.equal(1, cellOf(computed, { cy = bar.y + bar.h / 2 }))
      assert.are.equal(dotOn(computed, 2).cy, bar.y + bar.h / 2)
    end)

    it("follows the framing when the user reframes the diagram under it", function()
      -- Framed from the fifth instead, the seventh fret is the third cell down
      -- and the bar moves with everything else.
      local barred = voicing.setBaseFret(voicing.setBarre(Bm, 7, 2, 6), 5)
      local computed = layout.compute(barred, 1024, 1024)
      assert.are.equal(3, cellOf(computed, { cy = barreBody(computed).y
        + barreBody(computed).h / 2 }))
    end)

    it("draws no bar for a barre the window cannot show", function()
      -- Same rule as a dot outside the window: what cannot be drawn in place is
      -- not drawn at the edge instead.
      local high = voicing.setBarre(assert(voicing.parse("x32010", "C")), 9, 1, 6)
      assert.are.equal(0, #withRole(layout.compute(high, 1024, 1024), "barre"))
    end)

    it("draws no bar at all for a barre shape nobody barred", function()
      local unbarred = assert(voicing.parse("133211", "F"))
      assert.are.equal(0, #withRole(layout.compute(unbarred, 1024, 1024), "barre"))
    end)

    it("still draws the dots of the strings the bar covers", function()
      -- The dot is a fact about the string and the bar a fact about the finger.
      -- They coincide at this thickness, so the choice is invisible today — but
      -- suppressing the dots would make the fretted strings disappear the day
      -- the style pass thins the bar.
      local computed = layout.compute(F, 1024, 1024)
      assert.are.equal(6, #withRole(computed, "dot"))
    end)

    it("keeps drawing the bar while the chord string beside it is retyped", function()
      -- The whole chain the window runs on every keystroke: parse the field
      -- against the chord being edited, then draw whatever comes back. A chord
      -- string cannot say "barred", so if parsing replaced the voicing instead
      -- of merging into it the bar would vanish mid-word — and the user would
      -- find out weeks later, in a diagram they trusted.
      local edited = F
      for n = 1, #"133214" do
        local parsed = voicing.parse(("133214"):sub(1, n), nil, edited)
        if parsed then edited = parsed end

        local bar = barreBody(layout.compute(edited, 1024, 1024))
        assert.is_table(bar)
        assert.are.equal(withRole(layout.compute(edited, 1024, 1024), "string")[1].x1, bar.x)
      end
      assert.are.equal("133214", voicing.toText(edited))
    end)
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

    it("reports absolute frets when the window starts above the nut", function()
      -- The window shows frets 7 to 11, so the cells map to those numbers and
      -- not to 1 to 5. A click has to mean the fret the user can see.
      local computed = layout.compute(Bm, 800, 600)
      for _, index in ipairs({ 2, 3, 4, 5, 6 }) do
        local dot = dotOn(computed, index)
        local hitString, hitFret = layout.cellAt(computed, dot.cx * 800, dot.cy * 600)
        assert.are.equal(index, hitString)
        assert.are.equal(Bm.frets[index], hitFret)
      end
    end)

    it("reads the marker row above the nut as the open string", function()
      local computed = layout.compute(C, 1024, 1024)
      local ring = withRole(computed, "open")[1]
      local hitString, hitFret = layout.cellAt(computed, ring.cx * 1024, ring.cy * 1024)
      assert.are.equal(4, hitString)
      assert.are.equal(voicing.OPEN, hitFret)
    end)

    it("maps a muted cross back to the string it was drawn for, and to muted", function()
      for s = 1, 6 do
        local frets = { 0, 0, 0, 0, 0, 0 }
        frets[s] = voicing.MUTED
        local computed = layout.compute(voicing.new({ frets = frets }), 800, 600)
        local cross = withRole(computed, "muted")[1]
        local hitString, hitFret = layout.cellAt(computed,
          centreX(cross) * 800, (cross.y1 + cross.y2) / 2 * 600)
        assert.are.equal(s, hitString)
        assert.are.equal(voicing.MUTED, hitFret)
      end
    end)

    it("maps every marker of a whole chord back to the string and fret it states", function()
      -- The round trip the grid's clicking rests on: whatever the layout drew
      -- for a string — a dot, a ring or a cross — clicking it addresses that
      -- same string and reports the position it is in.
      for _, v in ipairs({ C, Bm, assert(voicing.parse("x-0-9-9-7-x", "A")) }) do
        local computed = layout.compute(v, 800, 600)
        local seen = {}
        for _, p in ipairs(computed.primitives) do
          if p.role == "dot" or p.role == "open" or p.role == "muted" then
            local px = centreX(p) * 800
            local py = (p.cy or (p.y1 + p.y2) / 2) * 600
            local hitString, hitFret = layout.cellAt(computed, px, py)
            assert.are.equal(v.frets[hitString], hitFret,
              string.format("%s marker on string %s", p.role, tostring(hitString)))
            seen[hitString] = true
          end
        end

        -- And every string says something, so the round trip covers the chord
        -- rather than whichever markers happened to be drawn.
        for s = 1, v.strings do
          assert.is_true(seen[s] or false, "no marker on string " .. s)
        end
      end
    end)

    it("reports nothing for a point outside the diagram", function()
      local computed = layout.compute(C, 1024, 1024)
      assert.is_nil(layout.cellAt(computed, 0, 0))
      assert.is_nil(layout.cellAt(computed, 1023, 1023))
    end)
  end)
end)
