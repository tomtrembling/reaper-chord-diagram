--[[
@description Chord Diagram (spike)
@version 0.5.0
@author Tom Trembling
@noindex
@about
  NOT SHIPPED. This is the slice 002 tracer bullet, kept as the reference
  implementation of the REAPER call sequences it proved on the tester's
  machine. It lives in `ref/` rather than in the `Chord Diagram/` action
  folder, and carries `@noindex`, so ReaPack neither offers it nor installs
  it: a second "Chord Diagram" package sitting next to the real one is an
  invitation to install the wrong one. Read it, copy from it, do not ship it.

  Tracer bullet for the chord diagram plugin. Renders a HARDCODED voicing to
  PNGs and attaches them to the selected empty items.

  SETTLED, over four runs on the tester's machine:
    - LICE rendering, text drawing and the state-chunk write all work.
    - IMGRESOURCEFLAGS 3 on a square 1024 canvas. Flag 3 is the only value
      that never repeats the image; flags 1 and 5 keep the proportions but
      tile on wide items. At this canvas size the stretching is mild.
    - Stroke weight must be proportional to canvas size, never a fixed pixel
      count: thin lines vanish when REAPER scales the image down to item
      height.
    - The image path is stored relative to the project, so projects stay
      portable.

  This remains a SPIKE — the voicing is hardcoded and there is no UI. Its job
  was to prove the chain end to end and settle the display settings, which it
  has done. Slice 003 replaces it with the real modules.

  HOW TO USE
    - Save the project first.
    - Create an empty item on a track and select it.
    - Run this action.
@changelog
  0.5.0 Settle on IMGRESOURCEFLAGS 3 with the square 1024 canvas.
  0.4.0 Square 1024 canvas, more title clearance, sweep all flag values 1-7.
  0.3.0 Sweep canvas height and stroke weight; lines vanish when downscaled.
  0.2.0 Test padded canvases against the display flags.
  0.1.0 Initial spike.
--]]

--------------------------------------------------------------------------------
-- CONFIG — flip these and re-run; no new build needed.
--------------------------------------------------------------------------------

-- SETTLED (run 4): IMGRESOURCEFLAGS 3 on a square 1024 canvas. Flag 3 is the
-- only value that never repeats the image, and at this canvas size with these
-- margins its stretching is not objectionable. Confirmed by the tester across
-- all usable item sizes.
--
-- The sweep that established this is in git history. Add entries here to
-- compare again: 1 = centre/tile, 5 = full height, 2/4/6/7 undocumented.
local VARIANTS = {
  { flag = 3 },
}

local CONFIG = {
  SIZE           = 1024,  -- square, power of two. 512 also fine.
  STROKE         = 64,    -- line width = SIZE / STROKE. Smaller = thicker.
  RELATIVE_PATH  = true,
  NOTE_TEXT      = "Cadd9",
  DRAW_TEXT      = true,
  TRANSPARENT_BG = false, -- let the item colour show through instead of white
  LABEL_VARIANT  = false, -- flag settled; images no longer need labelling
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

say("Chord Diagram spike v0.5.0")
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
    "Select an EMPTY item.\n\nInsert one with Insert > Empty item, then select it.",
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
say("Settled configuration: IMGRESOURCEFLAGS 3 on a square %d canvas.", CONFIG.SIZE)
say("Flag 3 never repeats the image, and at this size the stretching is mild.")
say("")
say("Sanity check: exactly one diagram per item, readable at the item sizes")
say("you actually work at, and the chord name clear of the grid.")

flush()
