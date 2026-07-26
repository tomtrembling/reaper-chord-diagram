--[[
@description Chord Diagram (spike)
@version 0.4.0
@author Tom Trembling
@about
  Tracer bullet for the chord diagram plugin. Renders a HARDCODED voicing to
  PNGs and attaches them to the selected empty items.

  SETTLED SO FAR
    - LICE rendering, text and the state-chunk write all work.
    - Grid lines vanish when a large canvas is scaled down to item size, so
      stroke weight is proportional to canvas size rather than a fixed pixel
      count.
    - Flag 3 (stretch) never repeats but distorts. Flags 1 and 5 keep the
      proportions but tile into repeats on wide items.

  RUN 4 — three changes:
    1. Square power-of-two canvas (1024) for quality.
    2. More clearance between the chord name and the diagram, which were
       slightly crossing over.
    3. The requirement is FIT, NEVER REPEAT — and none of the flags tried so
       far does that. IMGRESOURCEFLAGS is a bitfield and the documented values
       only cover part of it: 1 = centre/tile, 3 = 1|2, 5 = 1|4. So bits 2 and
       4 exist on their own and the values 2, 4, 6 and 7 have never been tried.
       This run sweeps every value from 1 to 7 to find a true fit mode.

  Each image is labelled with its own flag value, so a screenshot identifies
  itself.

  HOW TO USE
    - Save the project first.
    - Create SEVEN empty items on a track and select them all.
    - Run this action.
    - Resize items wide, short, tall and narrow. Look for a flag that always
      shows exactly ONE diagram, never distorted and never repeated.
@changelog
  0.4.0 Square 1024 canvas, more title clearance, sweep all flag values 1-7.
  0.3.0 Sweep canvas height and stroke weight; lines vanish when downscaled.
  0.2.0 Test padded canvases against the display flags.
  0.1.0 Initial spike.
--]]

--------------------------------------------------------------------------------
-- CONFIG — flip these and re-run; no new build needed.
--------------------------------------------------------------------------------

-- One variant per selected item. IMGRESOURCEFLAGS is a bitfield; only 1, 3 and
-- 5 are documented, so this sweeps the whole low range looking for a mode that
-- fits the image without tiling it.
--   1 = centre/tile (documented)      2 = ? untested
--   3 = stretch (documented)          4 = ? untested
--   5 = full height (documented)      6 = ? untested
--   7 = ? untested
local VARIANTS = {
  { flag = 1 }, { flag = 2 }, { flag = 3 }, { flag = 4 },
  { flag = 5 }, { flag = 6 }, { flag = 7 },
}

local CONFIG = {
  SIZE           = 1024,  -- square, power of two. 512 also fine.
  STROKE         = 64,    -- line width = SIZE / STROKE. Smaller = thicker.
  RELATIVE_PATH  = true,
  NOTE_TEXT      = "Cadd9",
  DRAW_TEXT      = true,
  TRANSPARENT_BG = false, -- let the item colour show through instead of white
  LABEL_VARIANT  = true,
  FOLDER         = "chord-diagrams",
}

-- Vertical layout, as fractions of the canvas size. The gap between TITLE_BOT
-- and the markers is the clearance that was too tight in run 3.
local LAYOUT = {
  TITLE_TOP  = 0.04,
  TITLE_BOT  = 0.17,
  MARKER_Y   = 0.245,  -- the x/o row above the nut
  NUT_Y      = 0.31,
  GRID_BOT   = 0.95,
  GRID_LEFT  = 0.20,
  GRID_RIGHT = 0.80,
}

-- Cadd9 = x32030, low E to high E. -1 muted, 0 open, n fret.
local VOICING = { -1, 3, 2, 0, 3, 0 }
local CHORD_NAME = "Cadd9"

--------------------------------------------------------------------------------
-- Reporting
--------------------------------------------------------------------------------

local lines, failures = {}, 0

local function say(fmt, ...)
  lines[#lines + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
end

local function stage(label, fn)
  local ok, result = pcall(fn)
  if not ok then
    failures = failures + 1
    say("  FAIL   %s\n           %s", label, tostring(result))
    return nil
  end
  say("  ok     %s", label)
  return result == nil and true or result
end

local function flush()
  reaper.ShowConsoleMsg(table.concat(lines, "\n") .. "\n")
end

--------------------------------------------------------------------------------
-- Environment
--------------------------------------------------------------------------------

local SEP = package.config:sub(1, 1)

say("Chord Diagram spike v0.4.0")
say("REAPER %s   %s", reaper.GetAppVersion(), reaper.GetOS())
say("Canvas %dx%d, stroke %dpx", CONFIG.SIZE, CONFIG.SIZE,
  math.floor(CONFIG.SIZE / CONFIG.STROKE))
say("")

if not reaper.APIExists("JS_LICE_CreateBitmap") then
  reaper.ShowMessageBox(
    "js_ReaScriptAPI is not installed.\n\nInstall it via ReaPack, then restart REAPER.",
    "Missing dependency", 0)
  return
end

local _, projfn = reaper.EnumProjects(-1, "")
if projfn == nil or projfn == "" then
  reaper.ShowMessageBox("Save the project before running this.", "Project not saved", 0)
  return
end
local projdir = projfn:match("^(.*)[/\\][^/\\]*$")
say("Project dir: %s", projdir)

local items = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if reaper.CountTakes(item) == 0 then items[#items + 1] = item end
end

if #items == 0 then
  reaper.ShowMessageBox(
    "Select at least one EMPTY item.\n\nSeven gives one per flag value.",
    "No empty item selected", 0)
  return
end
say("Empty items selected: %d  (variants defined: %d)", #items, #VARIANTS)
if #items < #VARIANTS then
  say("NOTE: only flags 1-%d will be tested this run.", #items)
end
say("")

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

local WHITE, BLACK, CLEAR = 0xFFFFFFFF, 0xFF000000, 0x00000000

local function rect(bmp, x, y, w, h, colour)
  reaper.JS_LICE_FillRect(bmp, math.floor(x), math.floor(y),
    math.max(1, math.floor(w)), math.max(1, math.floor(h)), colour, 1.0, "COPY")
end

local function disc(bmp, cx, cy, r, colour)
  reaper.JS_LICE_FillCircle(bmp, math.floor(cx), math.floor(cy),
    math.floor(r), colour, 1.0, "COPY", true)
end

local function text(bmp, str, size, weight, x1, y1, x2, y2, colour)
  local gdi = reaper.JS_GDI_CreateFont(size, weight, 0, false, false, false, "Arial")
  if not gdi then return false end
  local font = reaper.JS_LICE_CreateFont()
  if not font then return false end
  reaper.JS_LICE_SetFontFromGDI(font, gdi, "")
  pcall(reaper.JS_LICE_SetFontColor, font, colour or BLACK)
  pcall(reaper.JS_LICE_SetFontBkColor, font, CONFIG.TRANSPARENT_BG and CLEAR or WHITE)
  reaper.JS_LICE_DrawText(bmp, font, str, #str, x1, y1, x2, y2)
  pcall(reaper.JS_LICE_DestroyFont, font)
  pcall(reaper.JS_GDI_DeleteObject, gdi)
  return true
end

--- Render one variant to a PNG. Returns the path relative to the project.
local function render(variant)
  local S      = CONFIG.SIZE
  local lineW  = math.max(2, math.floor(S / CONFIG.STROKE))
  local left   = S * LAYOUT.GRID_LEFT
  local right  = S * LAYOUT.GRID_RIGHT
  local nutY   = S * LAYOUT.NUT_Y
  local botY   = S * LAYOUT.GRID_BOT
  local markY  = S * LAYOUT.MARKER_Y

  local gridW     = right - left
  local stringGap = gridW / 5
  local fretGap   = (botY - nutY) / 5
  local dotR      = stringGap * 0.34
  local function stringX(i) return left + (i - 1) * stringGap end

  local bmp = reaper.JS_LICE_CreateBitmap(true, S, S)
  if not bmp then error("JS_LICE_CreateBitmap returned nil") end
  reaper.JS_LICE_Clear(bmp, CONFIG.TRANSPARENT_BG and CLEAR or WHITE)

  -- Nut: noticeably heavier than the frets.
  rect(bmp, left - lineW / 2, nutY - lineW, gridW + lineW, lineW * 2.5, BLACK)
  -- Frets
  for f = 1, 5 do
    rect(bmp, left - lineW / 2, nutY + f * fretGap, gridW + lineW, lineW, BLACK)
  end
  -- Strings
  for s = 1, 6 do
    rect(bmp, stringX(s) - lineW / 2, nutY, lineW, botY - nutY, BLACK)
  end

  -- Dots, and the open/muted row above the nut
  for s = 1, 6 do
    local fret, x = VOICING[s], stringX(s)
    if fret == -1 then
      local a, step = dotR * 0.75, math.max(1, lineW / 3)
      for d = -a, a, step do
        rect(bmp, x + d - lineW / 2, markY + d - lineW / 2, lineW, lineW, BLACK)
        rect(bmp, x + d - lineW / 2, markY - d - lineW / 2, lineW, lineW, BLACK)
      end
    elseif fret == 0 then
      disc(bmp, x, markY, dotR * 0.7, BLACK)
      disc(bmp, x, markY, dotR * 0.7 - lineW, CONFIG.TRANSPARENT_BG and CLEAR or WHITE)
    else
      disc(bmp, x, nutY + (fret - 0.5) * fretGap, dotR, BLACK)
    end
  end

  if CONFIG.DRAW_TEXT then
    text(bmp, CHORD_NAME, math.floor(S * (LAYOUT.TITLE_BOT - LAYOUT.TITLE_TOP)), 700,
      0, math.floor(S * LAYOUT.TITLE_TOP), S, math.floor(S * LAYOUT.TITLE_BOT))
  end

  local label = string.format("flag%d", variant.flag)
  if CONFIG.LABEL_VARIANT then
    text(bmp, label, math.max(11, math.floor(S * 0.045)), 700,
      math.floor(lineW), math.floor(S * 0.955), S, S, BLACK)
  end

  local rel = CONFIG.FOLDER .. SEP .. "spike-" .. label .. ".png"
  local abs = projdir .. SEP .. rel
  local ok = reaper.JS_LICE_WritePNG(abs, bmp, CONFIG.TRANSPARENT_BG and true or false)
  pcall(reaper.JS_LICE_DestroyBitmap, bmp)
  if ok == false then error("JS_LICE_WritePNG returned false") end
  if not reaper.file_exists(abs) then error("PNG not found after write: " .. abs) end

  return rel
end

stage("create image folder", function()
  reaper.RecursiveCreateDirectory(projdir .. SEP .. CONFIG.FOLDER, 0)
end)

--------------------------------------------------------------------------------
-- Attach
--------------------------------------------------------------------------------

local function withImage(chunk, filename, flags, note)
  chunk = chunk:gsub("\nRESOURCEFN [^\n]*", "")
  chunk = chunk:gsub("\nIMGRESOURCEFLAGS [^\n]*", "")
  chunk = chunk:gsub("\n<NOTES.-\n>", "")
  local block = string.format('\n<NOTES\n|%s\n>\nRESOURCEFN "%s"\nIMGRESOURCEFLAGS %d',
    note, filename, flags)
  local replaced, n = chunk:gsub("\n>%s*$", block .. "\n>\n")
  if n == 0 then error("could not find the end of the item chunk") end
  return replaced
end

reaper.Undo_BeginBlock()

for i, item in ipairs(items) do
  local variant = VARIANTS[i]
  if variant then
    stage(string.format("item %d: IMGRESOURCEFLAGS %d", i, variant.flag), function()
      local rel = render(variant)
      local stored = CONFIG.RELATIVE_PATH and rel or (projdir .. SEP .. rel)
      local ok, chunk = reaper.GetItemStateChunk(item, "", false)
      if not ok then error("GetItemStateChunk failed") end
      if not reaper.SetItemStateChunk(item,
        withImage(chunk, stored, variant.flag, CONFIG.NOTE_TEXT), false) then
        error("SetItemStateChunk failed")
      end
    end)
  end
end

reaper.Undo_EndBlock("Chord diagram spike", -1)
reaper.UpdateArrange()

--------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------

say("")
if failures == 0 then
  say("All steps completed.")
else
  say("%d step(s) FAILED — see above.", failures)
end
say("")
say("Each image is labelled with its flag value in the bottom-left corner.")
say("")
say("Flags 1, 3 and 5 are the documented ones and are already known:")
say("  1 centre/tile — right proportions, but repeats on wide items")
say("  3 stretch     — never repeats, but distorts")
say("  5 full height — right proportions, but repeats")
say("")
say("Flags 2, 4, 6 and 7 are UNDOCUMENTED and are the point of this run.")
say("Resize items wide, short, tall and narrow, and look for one that always")
say("shows exactly ONE diagram, correctly proportioned and never repeated.")
say("")
say("If one of them does that, it is the setting we ship.")

flush()
