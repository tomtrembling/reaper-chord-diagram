--- The one geometric definition of a chord diagram.
---
--- `compute` turns a voicing into a flat list of drawing primitives; the LICE
--- backend paints them into a PNG and the ImGui backend paints the same list on
--- screen. Nothing else may draw geometry, which is what stops the preview
--- drifting away from the exported image.
---
--- COORDINATES. Primitives live in a unit square: x and y run 0..1, and scalar
--- sizes (radius, thickness, text size) are fractions of that square's side. A
--- backend multiplies x by the surface width, y by its height, and scalars by
--- the smaller of the two. The rendered canvas is square, so in practice all
--- three are the same number.
---
--- PRIMITIVES are backend-neutral: `line`, `rect`, `circle` and `text`, with a
--- semantic `colour` ("ink" or "paper") and a `role` naming the part it plays.
--- There is nothing LICE- or ImGui-specific here.
---
--- LINES run from (x1, y1) to (x2, y2) and are `thickness` wide about that
--- segment. THE SEGMENT IS THE WHOLE LINE: a backend must not add a cap beyond
--- either end, because a line that is longer in one backend than the other is
--- the drift this module exists to prevent. Where an overhang is wanted — the
--- frets reach a half stroke past the outer strings — it is in the coordinates
--- here, so both backends get it and neither invents it.
---
--- TEXT is the one primitive the two backends cannot render identically, so
--- what each of its fields promises is worth stating exactly:
---
---   * `x`, `y`, `w`, `h` are a BOX, and `align` says where in that box the
---     string sits. Only "centre" is ever asked for, and it means centred on
---     both axes.
---   * `size` is the em size the text should be set at, and `weight` is
---     "bold" or absent.
---
--- ALIGNMENT IS A REQUEST, NOT A GUARANTEE, because centring needs the width of
--- the rendered string and only one of the two backends can measure one:
---
---   * `adapter.imgui` measures with `CalcTextSize` and honours `align`, but
---     draws at the ImGui window's own font size and weight, so `size` and
---     `weight` are dropped.
---   * `adapter.lice` honours `size` and `weight` — it builds the font — but
---     CANNOT honour `align`. js_ReaScriptAPI exposes no way to do it:
---     `JS_LICE_DrawText` passes a hard-coded 0 for LICE's `dtFlags`, so no
---     DT_CENTER ever reaches it, and `JS_LICE_MeasureText` measures LICE's
---     built-in 8-pixel bitmap font rather than the font that was set, so it
---     cannot say how wide the string will actually be. Both checked against
---     the extension's published source, not remembered. It therefore draws
---     from the top left of the box and the box acts as a clip.
---
--- So a box is also a PROMISE THAT THE STRING FITS LEFT-ALIGNED IN IT: give
--- text a box it only fits in when centred and the LICE backend will clip it.
--- The known asymmetry, and the fix, are in `issues/hitl-queue.md` (T27, A5).
local voicing = require("core.voicing")

local M = {}

--- Vertical and horizontal proportions, as fractions of the canvas side.
---
--- SETTLED in slice 002 over four runs on the tester's machine, by eye. The gap
--- between TITLE_BOT and MARKER_Y is the title clearance that was too tight in
--- run 3. Do not re-derive these.
M.PROPORTIONS = {
  TITLE_TOP  = 0.04,
  TITLE_BOT  = 0.17,
  MARKER_Y   = 0.245, -- the open/muted row above the nut
  NUT_Y      = 0.31,
  GRID_BOT   = 0.95,
  GRID_LEFT  = 0.20,
  GRID_RIGHT = 0.80,
}

--- Line width as a fraction of the canvas side.
---
--- SETTLED in slice 002: stroke weight must be proportional to canvas size,
--- never a fixed pixel count. A fixed width vanishes when REAPER scales the
--- image down to the item's height.
M.STROKE = 1 / 64

--- The nut is drawn heavier than the frets so the framing reads at a glance.
local NUT_WEIGHT = 2.5

--- The position marker's height, as a fraction of the fret cell it labels.
---
--- Sized from the cell rather than given a number of its own, so it tracks the
--- grid instead of drifting away from it. It is smaller than the title because
--- it is subordinate to it: the name says what the chord is, the marker only
--- says where. The whole marker lives in the gutter left of the grid, which the
--- slice 002 proportions already leave empty.
local POSITION_HEIGHT = 0.6

--- Geometry shared by `compute` and `cellAt`, so a click lands on exactly what
--- was drawn.
--- @param v Voicing
local function grid(v)
  local p = M.PROPORTIONS
  local left, right = p.GRID_LEFT, p.GRID_RIGHT
  local top, bottom = p.NUT_Y, p.GRID_BOT
  return {
    left = left,
    right = right,
    top = top,
    bottom = bottom,
    markerY = p.MARKER_Y,
    stringGap = (right - left) / (v.strings - 1),
    fretGap = (bottom - top) / voicing.SPAN,
    baseFret = voicing.baseFret(v),
  }
end

--- The x of a string, counting from 1 = low E on the left.
local function stringX(g, index)
  return g.left + (index - 1) * g.stringGap
end

--- The y of the centre of a fret cell, counting from 1 = the cell below the top
--- of the window.
local function cellY(g, offset)
  return g.top + (offset - 0.5) * g.fretGap
end

--- Compute the diagram for a voicing on a surface of the given size.
--- @param v Voicing
--- @param width number
--- @param height number
--- @return { width: number, height: number, primitives: table[] }
function M.compute(v, width, height)
  local g = grid(v)
  local out = {}

  local function add(primitive)
    out[#out + 1] = primitive
    return primitive
  end

  -- The line closing the top of the window. It is the nut, drawn heavier so the
  -- framing reads at a glance, only when the window starts at the top of the
  -- neck; higher up it is an ordinary fret like the five below it, and the
  -- position marker says which. Backends key off the role, so the role has to
  -- tell the truth about which of the two it is.
  local nutInView = g.baseFret == 1
  add({
    kind = "line", role = nutInView and "nut" or "fret", colour = "ink",
    x1 = g.left - M.STROKE / 2, y1 = g.top,
    x2 = g.right + M.STROKE / 2, y2 = g.top,
    thickness = nutInView and M.STROKE * NUT_WEIGHT or M.STROKE,
  })

  -- The five frets below it. The span is fixed, so this count never varies with
  -- the framing.
  for f = 1, voicing.SPAN do
    add({
      kind = "line", role = "fret", colour = "ink",
      x1 = g.left - M.STROKE / 2, y1 = g.top + f * g.fretGap,
      x2 = g.right + M.STROKE / 2, y2 = g.top + f * g.fretGap,
      thickness = M.STROKE,
    })
  end

  -- Position marker, naming the fret the window starts at. Only when the nut is
  -- out of view: with the nut drawn, the window can only start at the first
  -- fret and saying so would be noise. It sits on the first cell, so the fret it
  -- names is the one the cell beside it is.
  if not nutInView then
    local h = g.fretGap * POSITION_HEIGHT
    add({
      kind = "text", role = "position", colour = "ink",
      text = string.format("%dfr", g.baseFret),
      x = 0, y = cellY(g, 1) - h / 2,
      w = g.left - M.STROKE * 2, h = h,
      size = h, align = "centre",
    })
  end

  -- Strings, low E on the left.
  for s = 1, v.strings do
    add({
      kind = "line", role = "string", colour = "ink",
      x1 = stringX(g, s), y1 = g.top,
      x2 = stringX(g, s), y2 = g.bottom,
      thickness = M.STROKE,
    })
  end

  local dotR = g.stringGap * 0.34

  -- Barres: one finger laid flat across several strings, drawn as a capsule
  -- exactly as wide as the dots it stands in for — a rectangle from the first
  -- string it covers to the last, with a round cap on each end. Three
  -- primitives rather than one thick line because NEITHER BACKEND CAN ROUND THE
  -- END OF A LINE: ImGui's draw list takes no cap style, and the LICE backend
  -- fills a rectangle. A thick line would give a bar with square ends, and
  -- asking a backend for round ones is asking it to invent geometry. A filled
  -- rect and a filled circle are drawn identically by both.
  --
  -- Drawn BEFORE the dots, so a dot at a barred fret sits on top of the bar
  -- rather than under it. Nothing is suppressed: the dot is a fact about the
  -- string and the bar is a fact about the finger, and at this thickness they
  -- coincide exactly, so the two are visually one shape. Should the style pass
  -- ever thin the bar, the fretted strings must not silently vanish with it.
  --
  -- A bar outside the window is skipped, on the same rule as a dot outside it.
  for _, b in ipairs(v.barres or {}) do
    local cell = b.fret - g.baseFret + 1
    local from, to = math.min(b.from, b.to), math.max(b.from, b.to)
    if cell >= 1 and cell <= voicing.SPAN and from >= 1 and to <= v.strings then
      local x1, x2, cy = stringX(g, from), stringX(g, to), cellY(g, cell)
      add({
        kind = "rect", role = "barre", colour = "ink",
        x = x1, y = cy - dotR, w = x2 - x1, h = dotR * 2,
      })
      for _, x in ipairs({ x1, x2 }) do
        add({
          kind = "circle", role = "barre", colour = "ink", filled = true,
          cx = x, cy = cy, r = dotR,
        })
      end
    end
  end

  -- Dots, one per fretted string, positioned relative to the top of the WINDOW
  -- rather than the nut, so that a high-position voicing lands in the same five
  -- cells an open chord does.
  --
  -- A fret outside the window is skipped. That only happens for a shape wider
  -- than the five frets the span allows, which no framing can show whole; the
  -- alternative is a dot painted off the edge of the diagram.
  for s = 1, v.strings do
    local fret = v.frets[s]
    local cell = fret - g.baseFret + 1
    if fret > voicing.OPEN and cell >= 1 and cell <= voicing.SPAN then
      add({
        kind = "circle", role = "dot", colour = "ink", filled = true,
        cx = stringX(g, s), cy = cellY(g, cell), r = dotR,
      })
    end
  end

  -- Open rings and muted crosses, on the row above the top of the window.
  --
  -- They are drawn whatever the framing. A string can ring open under a shape
  -- too high to show the nut, and a songbook still marks it with a ring above
  -- the diagram, so the row is not conditional on the nut being in view.
  local ringR = dotR * 0.7
  local crossArm = dotR * 0.75
  for s = 1, v.strings do
    local fret, x = v.frets[s], stringX(g, s)
    if fret == voicing.MUTED then
      add({
        kind = "line", role = "muted", colour = "ink", thickness = M.STROKE,
        x1 = x - crossArm, y1 = g.markerY - crossArm,
        x2 = x + crossArm, y2 = g.markerY + crossArm,
      })
      add({
        kind = "line", role = "muted", colour = "ink", thickness = M.STROKE,
        x1 = x - crossArm, y1 = g.markerY + crossArm,
        x2 = x + crossArm, y2 = g.markerY - crossArm,
      })
    elseif fret == voicing.OPEN then
      add({
        kind = "circle", role = "open", colour = "ink", filled = false,
        cx = x, cy = g.markerY, r = ringR - M.STROKE / 2, thickness = M.STROKE,
      })
    end
  end

  -- Title. Its band ends well above the marker row; that clearance was tuned by
  -- eye in slice 002 after the name and the grid crossed over.
  if v.name and v.name ~= "" then
    local p = M.PROPORTIONS
    add({
      kind = "text", role = "title", colour = "ink", text = v.name,
      x = 0, y = p.TITLE_TOP, w = 1, h = p.TITLE_BOT - p.TITLE_TOP,
      size = p.TITLE_BOT - p.TITLE_TOP, weight = "bold", align = "centre",
    })
  end

  return { width = width, height = height, voicing = v, primitives = out }
end

--- Which string and fret is at this point on the surface?
---
--- Coordinates are in the surface's own units — the same width and height that
--- were passed to `compute`. The geometry comes from the same `grid` the
--- primitives were drawn from, so a click lands on exactly what is displayed.
---
--- Returns the string index (1 = low E) and the absolute fret. Inside the grid
--- that is the fret the cell stands for; on the row above the top of the window
--- it is `voicing.OPEN` or `voicing.MUTED`, whichever that string is currently
--- marked with. Every marker the diagram draws therefore maps back to the
--- string and the position it was drawn for. Returns nil for a point outside
--- the diagram.
--- @param computed { width: number, height: number, voicing: Voicing }
--- @param x number
--- @param y number
--- @return integer|nil stringIndex
--- @return integer|nil fret
function M.cellAt(computed, x, y)
  local v = computed.voicing
  local g = grid(v)
  local nx, ny = x / computed.width, y / computed.height

  local index = math.floor((nx - g.left) / g.stringGap + 0.5) + 1
  if index < 1 or index > v.strings then
    return nil
  end
  if math.abs(nx - stringX(g, index)) > g.stringGap / 2 then
    return nil
  end

  if ny >= g.top and ny <= g.bottom then
    local offset = math.floor((ny - g.top) / g.fretGap) + 1
    offset = math.min(offset, voicing.SPAN)
    return index, offset + g.baseFret - 1
  end

  -- The row above the top of the window. It holds one marker per string and
  -- which marker that is depends on the chord, so the row answers with the
  -- state the string is actually in: a cross reports MUTED and a ring reports
  -- OPEN, and a string with a dot below reports OPEN because that is what the
  -- empty space up there would become. Every marker the layout draws therefore
  -- maps back to the string and fret it was drawn for, crosses included.
  if ny >= g.markerY - g.fretGap / 2 and ny < g.top then
    return index, v.frets[index] == voicing.MUTED and voicing.MUTED or voicing.OPEN
  end

  return nil
end

return M
