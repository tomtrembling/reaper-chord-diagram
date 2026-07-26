--[[
@description Chord Diagram (spike)
@version 0.1.0
@author Tom Trembling
@about
  Tracer bullet for the chord diagram plugin. Renders a HARDCODED voicing to a
  PNG and attaches it to the selected empty item(s).

  This is a spike, not the plugin. It exists to answer three questions in a
  single run, because the developer has no REAPER install and every test is a
  round trip to another machine:

    1. Can js_ReaScriptAPI's LICE functions produce an acceptable diagram?
    2. Does text rendering work, and on Windows specifically?
    3. Which IMGRESOURCEFLAGS value frames a portrait image correctly?

  HOW TO USE
    - Save the project first (the image path is relative to the project).
    - Create one to three EMPTY items on a track and select them.
    - Run this action.
    - Read the report in the console window that opens.

  With three items selected, each gets a different display flag so they can be
  compared side by side. Resize them taller and see which one looks right.
@changelog
  Initial spike.
--]]

--------------------------------------------------------------------------------
-- CONFIG — flip these and re-run; no new build needed.
--------------------------------------------------------------------------------

local CONFIG = {
  -- Display flag applied to the 1st, 2nd, 3rd selected item respectively.
  --   1 = centre/tile    3 = stretch image+text    5 = full-height image
  FLAGS = { 5, 3, 1 },

  -- Store the image path relative to the project (goal), or absolute (fallback
  -- if the relative form does not resolve).
  RELATIVE_PATH = true,

  -- Item notes text. IMGRESOURCEFLAGS is documented as absent when notes are
  -- empty, so this defaults to non-empty. Set to "" to see whether the image
  -- still displays, and whether note text collides with the picture.
  NOTE_TEXT = "Cadd9",

  -- Draw the title text. Set false to isolate shape rendering if text fails.
  DRAW_TEXT = true,

  -- Canvas size in pixels.
  WIDTH = 400,
  HEIGHT = 520,

  FOLDER = "chord-diagrams",
}

-- The hardcoded voicing: Cadd9 = x32030, strings low-E to high-E.
-- -1 = muted, 0 = open, n = fret.
local VOICING = { -1, 3, 2, 0, 3, 0 }
local CHORD_NAME = "Cadd9"

--------------------------------------------------------------------------------
-- Reporting
--------------------------------------------------------------------------------

local lines, failures = {}, 0

local function say(fmt, ...)
  local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  lines[#lines + 1] = msg
end

--- Run one stage, capturing any error rather than aborting the whole script.
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

say("Chord Diagram spike")
say("REAPER %s   %s", reaper.GetAppVersion(), reaper.GetOS())
say("")

if not reaper.APIExists("JS_LICE_CreateBitmap") then
  reaper.ShowMessageBox(
    "js_ReaScriptAPI is not installed.\n\n" ..
    "Install it via ReaPack (Extensions > ReaPack > Browse packages, " ..
    "search for js_ReaScriptAPI), then restart REAPER.",
    "Missing dependency", 0)
  return
end
say("js_ReaScriptAPI present")

-- Project directory
local _, projfn = reaper.EnumProjects(-1, "")
if projfn == nil or projfn == "" then
  reaper.ShowMessageBox(
    "Save the project before running this.\n\n" ..
    "The diagram is written into a folder next to the project file.",
    "Project not saved", 0)
  return
end
local projdir = projfn:match("^(.*)[/\\][^/\\]*$")
say("Project dir: %s", projdir)

-- Selected items
local items = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if reaper.CountTakes(item) == 0 then
    items[#items + 1] = item
  end
end

if #items == 0 then
  reaper.ShowMessageBox(
    "Select at least one EMPTY item.\n\n" ..
    "Insert one with Insert > Empty item, then select it.\n" ..
    "Select three to compare the display flags side by side.",
    "No empty item selected", 0)
  return
end
say("Empty items selected: %d", #items)
say("")

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

local W, H = CONFIG.WIDTH, CONFIG.HEIGHT
local WHITE, BLACK = 0xFFFFFFFF, 0xFF000000

-- Layout geometry. Kept crude on purpose — this is a spike; the real version
-- computes this in a pure Lua layout module shared with the on-screen grid.
local marginX   = math.floor(W * 0.16)
local topY      = math.floor(H * 0.30)
local bottomY   = math.floor(H * 0.93)
local gridW     = W - marginX * 2
local stringGap = gridW / 5
local fretGap   = (bottomY - topY) / 5
local lineW     = math.max(2, math.floor(W / 160))
local dotR      = math.floor(stringGap * 0.30)

local function rect(bmp, x, y, w, h, colour)
  reaper.JS_LICE_FillRect(bmp, math.floor(x), math.floor(y),
    math.floor(w), math.floor(h), colour, 1.0, "COPY")
end

local function disc(bmp, cx, cy, r, colour)
  reaper.JS_LICE_FillCircle(bmp, math.floor(cx), math.floor(cy),
    math.floor(r), colour, 1.0, "COPY", true)
end

local function stringX(i) return marginX + (i - 1) * stringGap end

local bmp = stage("create bitmap", function()
  local b = reaper.JS_LICE_CreateBitmap(true, W, H)
  if not b then error("JS_LICE_CreateBitmap returned nil") end
  return b
end)
if not bmp then flush() return end

stage("clear canvas", function()
  reaper.JS_LICE_Clear(bmp, WHITE)
end)

stage("draw grid, dots and markers", function()
  -- Nut: thicker bar at the top of the grid.
  rect(bmp, marginX, topY - lineW * 2, gridW, lineW * 3, BLACK)

  -- Frets
  for f = 1, 5 do
    rect(bmp, marginX, topY + f * fretGap, gridW, lineW, BLACK)
  end

  -- Strings
  for s = 1, 6 do
    rect(bmp, stringX(s) - lineW / 2, topY, lineW, bottomY - topY, BLACK)
  end

  -- Dots, and open/muted markers above the nut
  local markY = topY - lineW * 6
  for s = 1, 6 do
    local fret = VOICING[s]
    local x = stringX(s)
    if fret == -1 then
      -- 'x' drawn as two crossed bars
      local a = dotR * 0.8
      for d = -a, a, 0.5 do
        rect(bmp, x + d, markY + d, lineW, lineW, BLACK)
        rect(bmp, x + d, markY - d, lineW, lineW, BLACK)
      end
    elseif fret == 0 then
      -- 'o' drawn as a filled disc with a white centre
      disc(bmp, x, markY, dotR * 0.75, BLACK)
      disc(bmp, x, markY, dotR * 0.75 - lineW, WHITE)
    else
      disc(bmp, x, topY + (fret - 0.5) * fretGap, dotR, BLACK)
    end
  end
end)

-- Text is isolated: if it fails, the shapes above are still written to disk and
-- the report says which half worked.
if CONFIG.DRAW_TEXT then
  stage("draw title text", function()
    local gdi = reaper.JS_GDI_CreateFont(math.floor(H * 0.10), 700, 0,
      false, false, false, "Arial")
    if not gdi then error("JS_GDI_CreateFont returned nil") end
    local font = reaper.JS_LICE_CreateFont()
    if not font then error("JS_LICE_CreateFont returned nil") end
    reaper.JS_LICE_SetFontFromGDI(font, gdi, "")
    pcall(reaper.JS_LICE_SetFontColor, font, BLACK)
    pcall(reaper.JS_LICE_SetFontBkColor, font, WHITE)
    reaper.JS_LICE_DrawText(bmp, font, CHORD_NAME, #CHORD_NAME,
      0, math.floor(H * 0.10), W, math.floor(H * 0.26))
    pcall(reaper.JS_LICE_DestroyFont, font)
    pcall(reaper.JS_GDI_DeleteObject, gdi)
  end)
else
  say("  --     title text skipped (DRAW_TEXT = false)")
end

--------------------------------------------------------------------------------
-- Write PNG
--------------------------------------------------------------------------------

local relPath = CONFIG.FOLDER .. SEP .. "spike-" .. CHORD_NAME .. ".png"
local absPath = projdir .. SEP .. relPath

stage("create image folder", function()
  reaper.RecursiveCreateDirectory(projdir .. SEP .. CONFIG.FOLDER, 0)
end)

stage("write PNG", function()
  local ok = reaper.JS_LICE_WritePNG(absPath, bmp, false)
  if ok == false then error("JS_LICE_WritePNG returned false") end
end)

pcall(reaper.JS_LICE_DestroyBitmap, bmp)

local exists = reaper.file_exists(absPath)
say("  %s  file on disk: %s", exists and "ok    " or "FAIL  ", absPath)
if not exists then failures = failures + 1 end
say("")

--------------------------------------------------------------------------------
-- Attach to items via the state chunk
--------------------------------------------------------------------------------

local storedPath = CONFIG.RELATIVE_PATH and relPath or absPath

--- Insert the image reference into an item state chunk.
--- Existing notes and image lines are stripped first so re-running is idempotent.
local function withImage(chunk, filename, flags, note)
  chunk = chunk:gsub("\nRESOURCEFN [^\n]*", "")
  chunk = chunk:gsub("\nIMGRESOURCEFLAGS [^\n]*", "")
  chunk = chunk:gsub("\n<NOTES.-\n>", "")

  local block = string.format('\n<NOTES\n|%s\n>\nRESOURCEFN "%s"\nIMGRESOURCEFLAGS %d',
    note, filename, flags)

  -- Insert immediately before the chunk's closing '>'.
  local replaced, n = chunk:gsub("\n>%s*$", block .. "\n>\n")
  if n == 0 then error("could not find the end of the item chunk") end
  return replaced
end

reaper.Undo_BeginBlock()

for i, item in ipairs(items) do
  local flags = CONFIG.FLAGS[i] or CONFIG.FLAGS[#CONFIG.FLAGS]
  stage(string.format("item %d: attach image with IMGRESOURCEFLAGS %d", i, flags), function()
    local ok, chunk = reaper.GetItemStateChunk(item, "", false)
    if not ok then error("GetItemStateChunk failed") end
    local updated = withImage(chunk, storedPath, flags, CONFIG.NOTE_TEXT)
    if not reaper.SetItemStateChunk(item, updated, false) then
      error("SetItemStateChunk failed")
    end
  end)
end

reaper.Undo_EndBlock("Chord diagram spike", -1)
reaper.UpdateArrange()

--------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------

say("")
say("Stored image path: %s", storedPath)
say("  (%s — flip CONFIG.RELATIVE_PATH to try the other form)",
  CONFIG.RELATIVE_PATH and "relative to project" or "absolute")
say("")
if failures == 0 then
  say("All steps completed.")
else
  say("%d step(s) FAILED — see above.", failures)
end
say("")
say("Now look at the arrange view:")
say("  1. Does a chord diagram appear inside each item?")
say("  2. Drag an item taller — does the image scale, and stay undistorted?")
for i = 1, math.min(#items, #CONFIG.FLAGS) do
  say("     item %d uses IMGRESOURCEFLAGS %d", i, CONFIG.FLAGS[i])
end
say("  3. Is the title text there, and is it legible?")
say("  4. Is the diagram readable at a normal item height?")

flush()
