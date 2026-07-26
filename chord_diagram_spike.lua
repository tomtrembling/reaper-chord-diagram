--[[
@description Chord Diagram (spike)
@version 0.3.0
@author Tom Trembling
@about
  Tracer bullet for the chord diagram plugin. Renders a HARDCODED voicing to
  PNGs and attaches them to the selected empty items.

  RUN 1 established that LICE rendering, text and the state-chunk write all
  work. It also showed that none of the three display flags is usable on its
  own: flag 5 keeps proportions but tiles horizontally, flag 3 never tiles but
  distorts the diagram badly on short or narrow items, and flag 1 tiles without
  filling the item.

  RUN 2 settled the display flag: 1 (centre/tile), unpadded. Padding did not
  remove the tiling, and flag 1's repeats only appear at item widths that are
  not used in practice.

  RUN 3 tackles what run 2 exposed — grid lines VANISH at practical item sizes.
  This is a downscaling artefact rather than a lack of resolution: a 2px line in
  a 520px-tall image is 0.4% of its height, so at an 80px item height it becomes
  a quarter of a pixel and is dropped. Rendering larger makes it worse. The fix
  is heavier strokes relative to the canvas, and a canvas nearer the displayed
  size. This run sweeps both.

  Each variant writes its own settings into the corner of the image, so a
  screenshot identifies itself.

  HOW TO USE
    - Save the project first.
    - Create SIX empty items on a track and select them all.
    - Run this action.
    - Shrink the items to a realistic working height, then count the strings
      and fret lines in each. Which variants keep all of them?
@changelog
  0.3.0 Sweep canvas height and stroke weight; lines vanish when downscaled.
  0.2.0 Test padded canvases against the display flags.
  0.1.0 Initial spike.
--]]

--------------------------------------------------------------------------------
-- CONFIG — flip these and re-run; no new build needed.
--------------------------------------------------------------------------------

-- Each variant is applied to the correspondingly-numbered selected item.
--   flag = IMGRESOURCEFLAGS: 5 full-height, 3 stretch, 1 centre/tile
--   pad  = canvas width as a multiple of the diagram width. 1.0 is run 1's
--          behaviour; higher values add white padding either side.
-- Run 2 verdict: flag 1 with no padding is the choice. Padding did not remove
-- the tiling, and flag 1's repeats only appear at item widths that would not be
-- used in practice. Flag 3 stops repeats but stretches the diagram.
--
-- The real problem run 2 exposed is that grid lines VANISH at practical item
-- sizes. That is a downscaling artefact, not a lack of resolution: a 2px line
-- in a 520px-tall image is 0.4% of the height, so at an 80px item height it
-- becomes a quarter of a pixel and gets dropped. Rendering larger makes this
-- worse, not better.
--
-- Run 3 therefore sweeps two things: how tall the canvas is (less downscaling
-- is safer) and how heavy the strokes are relative to it. `stroke` is a
-- divisor — SMALLER means THICKER lines.
local VARIANTS = {
  { flag = 1, pad = 1.0, h = 520, stroke = 260 },  -- control: run-2 geometry
  { flag = 1, pad = 1.0, h = 520, stroke = 60  },
  { flag = 1, pad = 1.0, h = 520, stroke = 35  },
  { flag = 1, pad = 1.0, h = 260, stroke = 60  },
  { flag = 1, pad = 1.0, h = 260, stroke = 35  },
  { flag = 1, pad = 1.0, h = 160, stroke = 35  },
}

local CONFIG = {
  RELATIVE_PATH = true,
  NOTE_TEXT     = "Cadd9",
  DRAW_TEXT     = true,
  -- Transparent background instead of white, so the item's own colour shows
  -- through rather than the diagram sitting in a white box. The reference
  -- images from the manual workflow appear to be transparent PNGs.
  TRANSPARENT_BG = false,
  LABEL_VARIANT = true,   -- write "f1 h520 s60" into the image corner
  WIDTH         = 400,    -- base ratio only; variant.h drives actual size
  HEIGHT        = 520,
  FOLDER        = "chord-diagrams",
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

say("Chord Diagram spike v0.3.0")
say("REAPER %s   %s", reaper.GetAppVersion(), reaper.GetOS())
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
    "Select at least one EMPTY item.\n\n" ..
    "Six gives one per variant — see the top of the script.",
    "No empty item selected", 0)
  return
end
say("Empty items selected: %d  (variants defined: %d)", #items, #VARIANTS)
if #items < #VARIANTS then
  say("NOTE: only the first %d variants will be tested.", #items)
end
say("")

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

local WHITE, BLACK, CLEAR = 0xFFFFFFFF, 0xFF000000, 0x00000000

local function rect(bmp, x, y, w, h, colour)
  reaper.JS_LICE_FillRect(bmp, math.floor(x), math.floor(y),
    math.floor(w), math.floor(h), colour, 1.0, "COPY")
end

local function disc(bmp, cx, cy, r, colour)
  reaper.JS_LICE_FillCircle(bmp, math.floor(cx), math.floor(cy),
    math.floor(r), colour, 1.0, "COPY", true)
end

--- Draw text, returning false if the font could not be made.
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
  -- Canvas height drives everything; width keeps the original 400:520 ratio.
  local H       = variant.h or CONFIG.HEIGHT
  local W       = math.floor(H * (CONFIG.WIDTH / CONFIG.HEIGHT))
  local canvasW = math.floor(W * variant.pad)
  local offX    = math.floor((canvasW - W) / 2)

  local marginX   = math.floor(W * 0.16)
  local topY      = math.floor(H * 0.30)
  local bottomY   = math.floor(H * 0.93)
  local gridW     = W - marginX * 2
  local stringGap = gridW / 5
  local fretGap   = (bottomY - topY) / 5
  -- Stroke weight is proportional to canvas height, so that lines survive being
  -- scaled down to item size. A smaller divisor gives thicker lines.
  local lineW     = math.max(2, math.floor(H / (variant.stroke or 260)))
  local dotR      = math.floor(stringGap * 0.30)
  local function stringX(i) return offX + marginX + (i - 1) * stringGap end

  local bmp = reaper.JS_LICE_CreateBitmap(true, canvasW, H)
  if not bmp then error("JS_LICE_CreateBitmap returned nil") end
  reaper.JS_LICE_Clear(bmp, CONFIG.TRANSPARENT_BG and CLEAR or WHITE)

  -- Nut
  rect(bmp, offX + marginX, topY - lineW * 2, gridW, lineW * 3, BLACK)
  -- Frets
  for f = 1, 5 do
    rect(bmp, offX + marginX, topY + f * fretGap, gridW, lineW, BLACK)
  end
  -- Strings
  for s = 1, 6 do
    rect(bmp, stringX(s) - lineW / 2, topY, lineW, bottomY - topY, BLACK)
  end

  -- Dots and open/muted markers
  local markY = topY - lineW * 6
  for s = 1, 6 do
    local fret, x = VOICING[s], stringX(s)
    if fret == -1 then
      local a = dotR * 0.8
      for d = -a, a, 0.5 do
        rect(bmp, x + d, markY + d, lineW, lineW, BLACK)
        rect(bmp, x + d, markY - d, lineW, lineW, BLACK)
      end
    elseif fret == 0 then
      disc(bmp, x, markY, dotR * 0.75, BLACK)
      disc(bmp, x, markY, dotR * 0.75 - lineW, WHITE)
    else
      disc(bmp, x, topY + (fret - 0.5) * fretGap, dotR, BLACK)
    end
  end

  if CONFIG.DRAW_TEXT then
    text(bmp, CHORD_NAME, math.floor(H * 0.10), 700,
      offX, math.floor(H * 0.10), offX + W, math.floor(H * 0.26))
  end

  local label = string.format("f%d h%d s%d", variant.flag, H, variant.stroke or 260)
  if CONFIG.LABEL_VARIANT then
    -- Bold and black: a faint label would vanish at the same sizes the grid
    -- lines do, which would defeat the point of labelling.
    text(bmp, label, math.max(11, math.floor(H * 0.07)), 700,
      math.floor(lineW), H - math.floor(H * 0.09), canvasW, H, BLACK)
  end

  local rel = CONFIG.FOLDER .. SEP .. "spike-" .. label:gsub("[ .]", "") .. ".png"
  local abs = projdir .. SEP .. rel
  local ok = reaper.JS_LICE_WritePNG(abs, bmp, CONFIG.TRANSPARENT_BG and true or false)
  pcall(reaper.JS_LICE_DestroyBitmap, bmp)
  if ok == false then error("JS_LICE_WritePNG returned false") end
  if not reaper.file_exists(abs) then error("PNG not found after write: " .. abs) end

  return rel, abs, canvasW
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
    stage(string.format("item %d: flag %d, canvas height %d, stroke 1/%d",
      i, variant.flag, variant.h or CONFIG.HEIGHT, variant.stroke or 260), function()
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
say("Labels in the bottom-left of each image read:  f<flag> h<canvas height> s<stroke divisor>")
say("A SMALLER stroke number means THICKER lines.")
say("")
say("The question this run answers: which one keeps all six strings and all")
say("five fret lines visible at the item size you would actually use?")
say("")
say("  * shrink the items to a realistic working height")
say("  * count the strings and frets in each — any missing?")
say("  * of the ones that survive, which still looks like a chord chart")
say("    rather than a set of fat bars?")

flush()
