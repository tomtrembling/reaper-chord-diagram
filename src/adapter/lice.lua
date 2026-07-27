--- The LICE rendering backend: layout primitives to a PNG.
---
--- This module draws nothing of its own. It receives a primitive list from
--- `core.layout` and paints it, which is what guarantees the exported image and
--- the on-screen grid cannot drift apart.
---
--- Every js_ReaScriptAPI call here was proven on the tester's machine in slice
--- 002; REAPER is not installed on the development machine, so none of it can
--- be executed here. Do not change a signature without a run on Windows.
local M = {}

--- Semantic colours from the layout, resolved to ARGB.
---
--- The background is opaque white, settled in slice 002: an unfilled circle is
--- drawn as an ink disc with a paper disc punched out of it, which needs a
--- background to punch back to.
local COLOURS = {
  ink = 0xFF000000,
  paper = 0xFFFFFFFF,
}

--- @param colour string|nil
local function argb(colour)
  return COLOURS[colour or "ink"] or COLOURS.ink
end

--- @param bmp userdata
local function fillRect(bmp, x, y, w, h, colour)
  reaper.JS_LICE_FillRect(bmp, math.floor(x), math.floor(y),
    math.max(1, math.floor(w)), math.max(1, math.floor(h)), colour, 1.0, "COPY")
end

--- @param bmp userdata
local function fillCircle(bmp, cx, cy, r, colour)
  reaper.JS_LICE_FillCircle(bmp, math.floor(cx), math.floor(cy),
    math.max(1, math.floor(r)), colour, 1.0, "COPY", true)
end

--- Draw a thick line.
---
--- Axis-aligned lines — every part of the grid — become a single filled rect.
--- Anything on the diagonal, which in practice means the muted-string cross, is
--- stepped as a run of small squares; that is how the spike drew it and how it
--- was signed off.
---
--- THE LINE ENDS WHERE THE LAYOUT SAYS IT ENDS. Thickness is spread about the
--- segment, never along it: the rect runs from one endpoint to the other and
--- the stepped run is inset by half a thickness so its end squares stop at the
--- endpoints rather than straddling them. Adding half a thickness at each end
--- instead — as this did until the alignment pass — makes every line in the PNG
--- one stroke longer than the same line on screen, which is invisible on the
--- strings but not on the nut or on the muted cross, whose arms are only about
--- twice a stroke long to begin with. `core.layout` already puts the overhang
--- the frets want into their coordinates, so a backend adding its own is
--- drawing geometry nobody asked for.
local function drawLine(bmp, x1, y1, x2, y2, thickness, colour)
  local t = math.max(2, thickness)
  if math.abs(y1 - y2) < 1 then
    fillRect(bmp, math.min(x1, x2), y1 - t / 2, math.abs(x2 - x1), t, colour)
    return
  end
  if math.abs(x1 - x2) < 1 then
    fillRect(bmp, x1 - t / 2, math.min(y1, y2), t, math.abs(y2 - y1), colour)
    return
  end
  local dx, dy = x2 - x1, y2 - y1
  local length = math.sqrt(dx * dx + dy * dy)
  local inset = math.min(t / 2, length / 2) / length
  local ax, ay = x1 + dx * inset, y1 + dy * inset
  local bx, by = x2 - dx * inset, y2 - dy * inset
  local steps = math.max(1, math.ceil(length * (1 - 2 * inset) / math.max(1, t / 3)))
  for i = 0, steps do
    local p = i / steps
    fillRect(bmp, ax + (bx - ax) * p - t / 2, ay + (by - ay) * p - t / 2, t, t, colour)
  end
end

--- Draw text inside a box.
---
--- The GDI font is built, handed to LICE and destroyed per call. Arial is named
--- because it exists on both macOS and Windows; the whole sequence was the most
--- platform-sensitive part of slice 002 and it is reproduced here unchanged.
---
--- `p.align` IS DELIBERATELY NOT HONOURED, and this is the one place the two
--- backends disagree about what a primitive means. It is not an oversight and
--- it is not fixable with the API this plugin has. Read off js_ReaScriptAPI's
--- published source rather than remembered:
---
---   * `JS_LICE_DrawText(bitmap, font, text, len, x1, y1, x2, y2)` takes no
---     format argument. It calls LICE's `DrawText` with a hard-coded `0` for
---     `dtFlags` — the author's own comment says "I don't know what UINT
---     dtFlags does, so make 0" — and 0 is `DT_TOP | DT_LEFT`. There is no
---     DT_CENTER to pass and no overload that accepts one.
---   * `JS_LICE_MeasureText(text)` exists, since v0.985, and answers a width
---     and a height. IT IS USELESS HERE: it forwards to LICE_MeasureText, which
---     takes no font and walks the string against LICE's built-in bitmap font
---     at a flat 8 pixels per character. It would report the same width for
---     8pt Arial and for the 133-pixel bold title.
---
--- So the text is drawn from the top left of the box, and the box clips it. The
--- one confirmed route to a centred string is a different drawing engine —
--- `JS_LICE_GetDC` on the bitmap, then `JS_GDI_DrawText` with "HCENTER", which
--- does map its align string onto real DT_ flags — and swapping the proven text
--- path for an unproven one, on a machine that cannot run either, would risk
--- no title at all in place of a title on the left. That call is the developer's
--- to make with a REAPER in front of them: `issues/hitl-queue.md`, T27 and A5.
local function drawText(bmp, p, x, y, w, h, size)
  local gdi = reaper.JS_GDI_CreateFont(math.floor(size),
    p.weight == "bold" and 700 or 400, 0, false, false, false, "Arial")
  if not gdi then return false end
  local font = reaper.JS_LICE_CreateFont()
  if not font then
    pcall(reaper.JS_GDI_DeleteObject, gdi)
    return false
  end
  reaper.JS_LICE_SetFontFromGDI(font, gdi, "")
  pcall(reaper.JS_LICE_SetFontColor, font, argb(p.colour))
  pcall(reaper.JS_LICE_SetFontBkColor, font, COLOURS.paper)
  reaper.JS_LICE_DrawText(bmp, font, p.text, #p.text,
    math.floor(x), math.floor(y), math.floor(x + w), math.floor(y + h))
  pcall(reaper.JS_LICE_DestroyFont, font)
  pcall(reaper.JS_GDI_DeleteObject, gdi)
  return true
end

--- Paint one primitive onto the bitmap.
--- @param scale { x: number, y: number, s: number }
local function paint(bmp, p, scale)
  local colour = argb(p.colour)
  if p.kind == "line" then
    drawLine(bmp, p.x1 * scale.x, p.y1 * scale.y, p.x2 * scale.x, p.y2 * scale.y,
      p.thickness * scale.s, colour)
  elseif p.kind == "rect" then
    fillRect(bmp, p.x * scale.x, p.y * scale.y, p.w * scale.x, p.h * scale.y, colour)
  elseif p.kind == "circle" then
    if p.filled then
      fillCircle(bmp, p.cx * scale.x, p.cy * scale.y, p.r * scale.s, colour)
    else
      local t = (p.thickness or 0) * scale.s
      fillCircle(bmp, p.cx * scale.x, p.cy * scale.y, p.r * scale.s + t / 2, colour)
      fillCircle(bmp, p.cx * scale.x, p.cy * scale.y, p.r * scale.s - t / 2, COLOURS.paper)
    end
  elseif p.kind == "text" then
    drawText(bmp, p, p.x * scale.x, p.y * scale.y, p.w * scale.x, p.h * scale.y,
      p.size * scale.s)
  end
end

--- Render a computed layout to a PNG on disk.
--- @param computed { width: number, height: number, primitives: table[] }
--- @param path string absolute path to write to
--- @return boolean ok
--- @return string|nil err
function M.writePNG(computed, path)
  local bmp = reaper.JS_LICE_CreateBitmap(true, computed.width, computed.height)
  if not bmp then
    return false, "JS_LICE_CreateBitmap returned nil."
  end
  reaper.JS_LICE_Clear(bmp, COLOURS.paper)

  local scale = {
    x = computed.width,
    y = computed.height,
    s = math.min(computed.width, computed.height),
  }
  for _, p in ipairs(computed.primitives) do
    paint(bmp, p, scale)
  end

  local ok = reaper.JS_LICE_WritePNG(path, bmp, false)
  pcall(reaper.JS_LICE_DestroyBitmap, bmp)

  if ok == false then
    return false, "JS_LICE_WritePNG returned false for " .. path
  end
  if not reaper.file_exists(path) then
    return false, "the PNG was not on disk after writing: " .. path
  end
  return true
end

return M
