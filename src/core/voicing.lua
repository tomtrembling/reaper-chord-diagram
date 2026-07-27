--- The chord voicing: the source of truth for a chord, and the only place that
--- knows how a voicing is written down.
local M = {}

--- @class Voicing
--- @field strings integer number of strings, low to high
--- @field frets integer[] one entry per string: -1 muted, 0 open, n fretted
--- @field name string free-text chord name

M.MUTED = -1
M.OPEN = 0

--- Standard six-string guitar. Parameterised so other instruments are additive
--- rather than a rewrite; only six strings are built in v1.
M.STRINGS = 6

--- Split a chord string into one token per string.
---
--- The compact form gives one character per string, which is unambiguous only
--- up to the ninth fret. The separated form for higher positions is added in
--- slice 004 and lands here.
--- @param text string
--- @return string[]
local function tokenise(text)
  local tokens = {}
  for c in text:gmatch("%S") do
    tokens[#tokens + 1] = c
  end
  return tokens
end

--- Read one token as a fret number.
--- @param token string
--- @return integer|nil fret
--- @return string|nil err
local function toFret(token)
  if token:lower() == "x" then
    return M.MUTED
  end
  local n = token:match("^%d+$") and tonumber(token)
  if not n then
    return nil, string.format("'%s' is not a fret number or an 'x' for a muted string.", token)
  end
  return math.tointeger(n)
end

--- Parse a chord string into a voicing.
---
--- Returns nil and a message the user can act on if the string cannot be read,
--- so callers can refuse the input rather than write a half-understood chord.
--- @param text string
--- @param name? string free-text chord name
--- @return Voicing|nil
--- @return string|nil err
function M.parse(text, name)
  local tokens = tokenise(tostring(text))
  if #tokens ~= M.STRINGS then
    return nil, string.format(
      "A chord needs one position per string: %d, low E to high E. Got %d in '%s'.",
      M.STRINGS, #tokens, text)
  end

  local frets = {}
  for i, token in ipairs(tokens) do
    local fret, err = toFret(token)
    if not fret then
      return nil, err
    end
    frets[i] = fret
  end

  return M.new({ frets = frets, name = name })
end

--- Build a voicing directly, for callers that already have the numbers.
--- @param opts? { frets?: integer[], name?: string, barres?: Barre[], baseFret?: integer }
--- @return Voicing
function M.new(opts)
  opts = opts or {}
  local frets = {}
  for i = 1, M.STRINGS do
    frets[i] = (opts.frets and opts.frets[i]) or M.MUTED
  end
  return {
    strings = M.STRINGS,
    frets = frets,
    fingers = {},
    barres = opts.barres or {},
    baseFret = opts.baseFret,
    name = opts.name or "",
  }
end

--- The number of frets the diagram shows at once. Settled at five.
M.SPAN = 5

--- The fret the top of the diagram sits at: 1 means the nut is drawn.
---
--- Derived, not stored, unless the caller has overridden it. The nut is shown
--- whenever the whole shape fits inside the span starting at the nut; anything
--- higher gets a window starting at its lowest fretted fret. The position
--- marker that names that fret is added in slice 004.
--- @param v Voicing
--- @return integer
function M.baseFret(v)
  if v.baseFret then
    return v.baseFret
  end
  local highest, lowest = 0, math.maxinteger
  for i = 1, v.strings do
    local fret = v.frets[i]
    if fret > M.OPEN then
      highest = math.max(highest, fret)
      lowest = math.min(lowest, fret)
    end
  end
  if highest <= M.SPAN then
    return 1
  end
  return lowest
end

--- Format a voicing back to a chord string.
--- @param v Voicing
--- @return string
function M.toText(v)
  local out = {}
  for i = 1, v.strings do
    local fret = v.frets[i]
    out[i] = fret == M.MUTED and "x" or tostring(fret)
  end
  return table.concat(out)
end

--- Everything about a voicing that affects the picture, in a stable order.
---
--- The name is included because it is drawn on the diagram as a title: two
--- items sharing a shape but not a name must not share an image file, or a
--- rename would leave the wrong title on screen.
--- @param v Voicing
--- @return string
local function canonical(v)
  local parts = { "v1", tostring(v.strings), tostring(M.baseFret(v)), M.toText(v) }

  local barres = {}
  for _, b in ipairs(v.barres or {}) do
    barres[#barres + 1] = string.format("%d:%d-%d", b.fret, b.from, b.to)
  end
  table.sort(barres)
  parts[#parts + 1] = table.concat(barres, ",")

  parts[#parts + 1] = v.name or ""
  return table.concat(parts, "|")
end

--- A stable hash of the voicing, used as its image filename.
---
--- FNV-1a over the canonical form, rendered as 16 lowercase hex digits: no
--- case and no separators, so it resolves identically on macOS and Windows.
--- Identical voicings therefore share one image file, and any edit produces a
--- new filename rather than overwriting one REAPER may still be displaying.
--- @param v Voicing
--- @return string
function M.fingerprint(v)
  local text = canonical(v)
  local hash = 0xcbf29ce484222325
  for i = 1, #text do
    hash = (hash ~ text:byte(i)) * 0x100000001b3
  end
  return string.format("%016x", hash)
end

return M
