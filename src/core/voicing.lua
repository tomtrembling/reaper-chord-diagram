--- The chord voicing: the source of truth for a chord, and the only place that
--- knows how a voicing is written down.
local M = {}

--- @class Barre a finger laid flat across several strings at one fret
--- @field fret integer
--- @field from integer lowest string it covers
--- @field to integer highest string it covers

--- @class Voicing
--- @field strings integer number of strings, low to high
--- @field frets integer[] one entry per string: -1 muted, 0 open, n fretted
--- @field fingers integer[] finger number per string; absent where unassigned
--- @field barres Barre[] explicit only, never inferred
--- @field baseFret integer|nil an override; nil means the framing is derived
--- @field name string free-text chord name

--- @class VoicingOpts
--- @field frets? integer[]
--- @field fingers? integer[]
--- @field barres? Barre[]
--- @field baseFret? integer
--- @field name? string

M.MUTED = -1
M.OPEN = 0

--- Standard six-string guitar. Parameterised so other instruments are additive
--- rather than a rewrite; only six strings are built in v1.
M.STRINGS = 6

--- What counts as a separator between positions in the separated form.
---
--- Guitarists write high voicings as `10-12-12-11-10-10`, so the hyphen is the
--- one this module EMITS. Spaces and commas are also accepted because they cost
--- nothing to allow and are what people type. None of them can occur in the
--- compact form, whose alphabet is digits and `x`, so a string containing any of
--- them is unambiguously the separated form.
local SEPARATORS = "%s,%-"

--- Split a chord string into one token per string.
---
--- Two notations, told apart by whether the text contains a separator at all:
--- the compact form gives one character per string, which is unambiguous only up
--- to the ninth fret, and the separated form gives one token per string for
--- anything higher. Surrounding whitespace is trimmed before the test, so a
--- padded compact string is still read as compact.
---
--- Runs of separators collapse and leading and trailing ones are ignored, so a
--- half-typed `10-12-` yields the two positions typed so far rather than an
--- empty one. Nothing here rejects anything: a token count that does not match
--- the instrument, or a token that is not a position, is the caller's error to
--- report.
--- @param text string
--- @return string[]
local function tokenise(text)
  local tokens = {}
  local trimmed = text:match("^%s*(.-)%s*$") or ""
  if trimmed:find("[" .. SEPARATORS .. "]") then
    for token in trimmed:gmatch("[^" .. SEPARATORS .. "]+") do
      tokens[#tokens + 1] = token
    end
  else
    for c in trimmed:gmatch(".") do
      tokens[#tokens + 1] = c
    end
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
---
--- `from` is the voicing being edited, if there is one. Barres, finger numbers
--- and a base-fret override are carried across from it, because none of them
--- can be written in the text form — parsing text has to MERGE into an
--- existing chord rather than replace it, or retyping one string of a barre
--- chord silently deletes the barre. This is a data-loss guard, not a
--- convenience.
--- @param text string
--- @param name? string free-text chord name
--- @param from? Voicing the voicing being edited
--- @return Voicing|nil
--- @return string|nil err
function M.parse(text, name, from)
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

  from = from or {}
  return M.new({
    frets = frets,
    fingers = from.fingers,
    barres = from.barres,
    -- Carried across only while it still frames the chord. See `M.baseFret`.
    baseFret = M.canFrame(frets, from.baseFret) and from.baseFret or nil,
    name = name,
  })
end

--- Build a voicing directly, for callers that already have the numbers.
--- @param opts? VoicingOpts
--- @return Voicing
function M.new(opts)
  opts = opts or {}
  local frets = {}
  for i = 1, M.STRINGS do
    frets[i] = (opts.frets and opts.frets[i]) or M.MUTED
  end
  local fingers = {}
  for i = 1, M.STRINGS do
    fingers[i] = opts.fingers and opts.fingers[i]
  end
  return {
    strings = M.STRINGS,
    frets = frets,
    fingers = fingers,
    barres = opts.barres or {},
    baseFret = opts.baseFret,
    name = opts.name or "",
  }
end

--- The number of frets the diagram shows at once. Settled at five.
M.SPAN = 5

--- Can a window starting at `base` show every fretted note of this shape?
---
--- The window is `M.SPAN` frets deep and the span never widens, so a shape can
--- sit outside the window a base fret would open. That is the test for whether
--- an override is still worth honouring, and it is public because the override
--- control in the UI needs the same answer before it offers a value.
--- @param frets integer[]
--- @param base integer|nil
--- @return boolean
function M.canFrame(frets, base)
  if not base then
    return false
  end
  for _, fret in ipairs(frets) do
    if fret > M.OPEN and (fret < base or fret > base + M.SPAN - 1) then
      return false
    end
  end
  return true
end

--- The fret the top of the diagram sits at: 1 means the nut is drawn.
---
--- Derived, not stored, unless the caller has overridden it. The nut is shown
--- whenever the whole shape fits inside the span starting at the nut; anything
--- higher gets a window starting at its lowest fretted fret, which the layout
--- labels with a position marker.
---
--- An open string does not force the nut into view. A shape that reaches past
--- the fifth fret cannot show both, and the fretted notes are the ones that
--- have to be drawn; the open string keeps its ring above the diagram, which is
--- how songbooks notate a high chord with an open string in it.
---
--- AN OVERRIDE IS HONOURED ONLY WHILE IT FRAMES THE CHORD. One that no longer
--- does is ignored rather than obeyed: obeying it would put the dots outside
--- the grid, which is not a framing the user could have meant.
--- @param v Voicing
--- @return integer
function M.baseFret(v)
  if M.canFrame(v.frets, v.baseFret) then
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

--- Move one string to a fret, leaving the rest of the chord alone.
---
--- Returns a NEW voicing; the one passed in is untouched. That is what makes
--- "Cancel leaves the item unchanged" structurally true rather than a promise
--- the UI has to keep: the voicing read off the item is never written to, so
--- there is nothing to put back.
---
--- Everything the text form cannot express — barres, finger numbers, the name —
--- is carried across, for the same reason `M.parse` merges rather than
--- replaces. A base-fret override is carried only while it still frames the
--- chord; see `M.baseFret`.
--- @param v Voicing
--- @param index integer which string, 1 = low E
--- @param fret integer `M.MUTED`, `M.OPEN`, or a fret number
--- @return Voicing
function M.setFret(v, index, fret)
  local frets = {}
  for i = 1, v.strings do
    frets[i] = v.frets[i]
  end
  if index >= 1 and index <= v.strings then
    frets[index] = fret
  end
  return M.new({
    frets = frets,
    fingers = v.fingers,
    barres = v.barres,
    baseFret = M.canFrame(frets, v.baseFret) and v.baseFret or nil,
    name = v.name,
  })
end

--- Apply a click on the cell addressing this string and fret.
---
--- A string is in one of three states — muted, open, or fretted — and the
--- diagram has two places to click, which between them reach all three:
---
---   * A CELL OF THE GRID places a dot at that fret, and clicking the same cell
---     again clears it back to MUTED. Muted rather than open, because deleting a
---     dot must not silently claim the string is sounded; only the row above the
---     nut says that.
---   * THE ROW ABOVE THE NUT toggles the string between open and muted, and
---     rings a fretted string open — that row is where a diagram says what a
---     string does when no finger is on it, so a click there is a statement
---     about the string rather than about the dot below it.
---
--- Two gestures, three states, and nothing is ever inferred. `fret` is whatever
--- `layout.cellAt` reported for the point clicked, so both `M.MUTED` and
--- `M.OPEN` arrive from the marker row and mean the same gesture.
--- @param v Voicing
--- @param index integer which string, 1 = low E
--- @param fret integer as `layout.cellAt` reports it
--- @return Voicing
function M.toggleFret(v, index, fret)
  local current = v.frets[index]
  if fret <= M.OPEN then
    return M.setFret(v, index, current == M.OPEN and M.MUTED or M.OPEN)
  end
  return M.setFret(v, index, current == fret and M.MUTED or fret)
end

--- The lowest fret that cannot be written as a single character.
local TWO_DIGIT = 10

--- The separator the separated form is written with. One of several accepted on
--- input; the only one produced on output.
M.SEPARATOR = "-"

--- Format a voicing back to a chord string.
---
--- The separated form appears exactly when it has to: one position at or above
--- the tenth fret makes every position in that chord ambiguous, so the whole
--- string switches rather than mixing notations. Below that the compact form is
--- what guitarists read, so it stays the default.
--- @param v Voicing
--- @return string
function M.toText(v)
  local out, separated = {}, false
  for i = 1, v.strings do
    local fret = v.frets[i]
    out[i] = fret == M.MUTED and "x" or tostring(fret)
    separated = separated or fret >= TWO_DIGIT
  end
  return table.concat(out, separated and M.SEPARATOR or "")
end

--- A voicing's barres as `fret:from-to` tokens, in the order they were added.
--- @param v Voicing
--- @return string[]
local function barreTokens(v)
  local out = {}
  for _, b in ipairs(v.barres or {}) do
    out[#out + 1] = string.format("%d:%d-%d", b.fret, b.from, b.to)
  end
  return out
end

--- Everything about a voicing that affects the picture, in a stable order.
---
--- The name is included because it is drawn on the diagram as a title: two
--- items sharing a shape but not a name must not share an image file, or a
--- rename would leave the wrong title on screen.
---
--- The "v1" here is the hash's own version, deliberately NOT `M.FORMAT`:
--- changing how a voicing is STORED must not change every image filename in
--- every existing project. The two versions move independently.
--- @param v Voicing
--- @return string
local function canonical(v)
  local parts = { "v1", tostring(v.strings), tostring(M.baseFret(v)), M.toText(v) }

  local barres = barreTokens(v)
  table.sort(barres)
  parts[#parts + 1] = table.concat(barres, ",")

  parts[#parts + 1] = v.name or ""
  return table.concat(parts, "|")
end

--------------------------------------------------------------------------------
-- Storage
--
-- How a voicing is written down. The stored form is ONE token: no whitespace,
-- no quote of any kind, nothing REAPER's own parser would try to interpret.
-- Everything else is percent-escaped into it.
--
-- That discipline was adopted for a line in a state chunk, and it is kept now
-- that the voicing lives in the item's extended state instead — extended state
-- is serialised into the same line-based project file, and a value that cannot
-- upset a text format is worth more than the few bytes it costs.
--
-- WHERE the token is put is deliberately not this module's business: `adapter
-- .item` owns that, which is why slice 005's move from a chunk line to
-- `P_EXT:chorddiagram` changed nothing here and broke no stored chord.
--
-- The format is versioned so a later change is detected rather than silently
-- misread, and it stores the fields nothing draws yet — finger numbers and
-- barres — so that adding a renderer for them never needs a migration.
--------------------------------------------------------------------------------

--- The version tag every stored voicing carries.
M.FORMAT = "v1"

--- Percent-escape everything outside a deliberately tiny alphabet.
---
--- What survives is what a REAPER state chunk line cannot misread: no
--- whitespace, no quote of any kind, and none of the format's own separators.
--- @param s string
--- @return string
local function escaped(s)
  return (tostring(s):gsub("[^%w._~%-]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

--- @param s string
--- @return string
local function unescaped(s)
  return (tostring(s):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

--- Read a stored token as an integer, or nil if it is absent or not a number.
--- @param token string|nil
--- @return integer|nil
local function integer(token)
  local n = tonumber(token or "")
  if not n then
    return nil
  end
  return math.tointeger(n)
end

--- A voicing's finger numbers, one per string, 0 where no finger is assigned.
--- @param v Voicing
--- @return string[]
local function fingerTokens(v)
  local out = {}
  for i = 1, v.strings do
    out[i] = tostring((v.fingers or {})[i] or 0)
  end
  return out
end

--- Write a voicing down as one chunk-safe token.
--- @param v Voicing
--- @return string
function M.encode(v)
  local frets = {}
  for i = 1, v.strings do
    frets[i] = tostring(v.frets[i])
  end
  return table.concat({
    M.FORMAT,
    "s=" .. tostring(v.strings),
    "f=" .. table.concat(frets, ","),
    -- Finger numbers are not rendered in v1, but they are stored, so a later
    -- version reads back chords captured before it existed. 0 means "none".
    "g=" .. table.concat(fingerTokens(v), ","),
    "b=" .. table.concat(barreTokens(v), ","),
    -- Written only when the user overrode it. An empty field means "derive",
    -- so reopening a chord cannot silently freeze framing that was automatic.
    "p=" .. (v.baseFret and tostring(v.baseFret) or ""),
    "n=" .. escaped(v.name or ""),
  }, ";")
end

--- Read a stored voicing back.
--- @param text string
--- @return Voicing|nil
--- @return string|nil err
function M.decode(text)
  text = tostring(text)

  -- The version is checked before anything else is read. A chord written by a
  -- later version must be refused outright: reading it with these rules would
  -- quietly produce a shape the user never played.
  local format = text:match("^(%w+)")
  if format ~= M.FORMAT then
    return nil, string.format(
      "This chord was stored in format '%s', and this version of the plugin reads '%s'.",
      tostring(format), M.FORMAT)
  end

  local fields = {}
  for key, value in text:gmatch("(%a+)=([^;]*)") do
    fields[key] = value
  end

  local frets = {}
  for token in (fields.f or ""):gmatch("[^,]+") do
    frets[#frets + 1] = integer(token)
  end

  -- A short or over-long fret list means the stored text was damaged. Padding
  -- it out would hand back a chord the user never played, which is worse than
  -- admitting the data is unreadable.
  local strings = integer(fields.s)
  if strings ~= M.STRINGS or #frets ~= M.STRINGS then
    return nil, string.format(
      "This chord's stored shape is damaged: %d positions for %s strings.",
      #frets, tostring(strings))
  end

  -- 0 is stored for a string with no finger assigned, and comes back as an
  -- absent entry rather than a finger numbered zero.
  local fingers = {}
  local nth = 0
  for token in (fields.g or ""):gmatch("[^,]+") do
    nth = nth + 1
    local finger = integer(token)
    if finger and finger > 0 then
      fingers[nth] = finger
    end
  end

  local barres = {}
  for fret, from, to in (fields.b or ""):gmatch("(%-?%d+):(%d+)%-(%d+)") do
    barres[#barres + 1] = { fret = integer(fret), from = integer(from), to = integer(to) }
  end

  return M.new({
    frets = frets,
    fingers = fingers,
    barres = barres,
    baseFret = integer(fields.p),
    name = unescaped(fields.n or ""),
  })
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
