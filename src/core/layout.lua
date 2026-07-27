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

  -- Nut, drawn as a heavier line at the top of the window.
  add({
    kind = "line", role = "nut", colour = "ink",
    x1 = g.left - M.STROKE / 2, y1 = g.top,
    x2 = g.right + M.STROKE / 2, y2 = g.top,
    thickness = M.STROKE * NUT_WEIGHT,
  })

  -- Frets, below the nut.
  for f = 1, voicing.SPAN do
    add({
      kind = "line", role = "fret", colour = "ink",
      x1 = g.left - M.STROKE / 2, y1 = g.top + f * g.fretGap,
      x2 = g.right + M.STROKE / 2, y2 = g.top + f * g.fretGap,
      thickness = M.STROKE,
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

  -- Dots, one per fretted string, positioned relative to the top of the window
  -- so that a high-position voicing lands in the same five cells.
  local dotR = g.stringGap * 0.34
  for s = 1, v.strings do
    local fret = v.frets[s]
    if fret > voicing.OPEN then
      add({
        kind = "circle", role = "dot", colour = "ink", filled = true,
        cx = stringX(g, s), cy = cellY(g, fret - g.baseFret + 1), r = dotR,
      })
    end
  end

  -- Open rings and muted crosses, on the marker row above the nut. Only drawn
  -- when the nut is in view: above the nut there is no "open" to speak of.
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
--- Returns the string index (1 = low E) and the absolute fret, where 0 means
--- the open/muted row above the nut. Returns nil for a point outside the
--- diagram.
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

  if ny >= g.markerY - g.fretGap / 2 and ny < g.top then
    return index, voicing.OPEN
  end

  return nil
end

return M
