--- The ImGui rendering backend: layout primitives to screen, plus input.
---
--- This module draws nothing of its own. It receives a primitive list from
--- `core.layout` and paints it, exactly as `adapter.lice` paints the same list
--- into a PNG. That shared definition is what guarantees the grid the user
--- clicks and the image they get cannot drift apart.
---
--- IT IS ALSO THE ONLY PLACE IN THE PROJECT THAT KNOWS HOW ReaImGui IS LOADED.
--- ReaImGui changed its entry point at 0.9: a script now asks the extension
--- where its Lua shim lives and requires a numbered version of the API, where
--- older scripts called `reaper.ImGui_*` directly. Which of the two an install
--- supports cannot be known from the development machine, so BOTH are resolved
--- here, behind one table, and nothing outside this file may learn which won.
--- See `M.binding` for the rule and the fallback.
---
--- REAPER is not installed on the development machine, so none of this can be
--- executed here. Every ImGui name used is listed in `FUNCTIONS` and
--- `CONSTANTS` below and checked at load time, so a name this file gets wrong
--- fails with a message saying which one rather than somewhere deep in a frame.
local layout = require("core.layout")
local voicing = require("core.voicing")

local M = {}

--- The ReaImGui API version this backend is written against.
---
--- Not the newest one. The shim exists precisely so a script can name an older
--- API and keep working on newer installs, so naming the version that
--- introduced the shim itself asks for the widest set of installs that can
--- answer. Raising this buys nothing until a call below needs it.
M.API_VERSION = "0.9"

--- Every ReaImGui function this backend calls. Nothing else may be used.
local FUNCTIONS = {
  "CreateContext",
  "Begin", "End", "SetNextWindowSize",
  "GetContentRegionAvail", "GetCursorScreenPos", "SameLine",
  "Button", "InvisibleButton", "IsItemClicked", "GetMousePos", "IsKeyPressed",
  "GetWindowDrawList", "CalcTextSize",
  "DrawList_AddLine", "DrawList_AddRectFilled",
  "DrawList_AddCircle", "DrawList_AddCircleFilled", "DrawList_AddText",
}

--- Every ReaImGui constant this backend reads.
---
--- Kept apart from the functions because the two binding styles disagree about
--- them: the versioned API hands back values, the older flat namespace hands
--- back getters that have to be called. Normalising that here is the whole
--- reason this list exists separately.
local CONSTANTS = {
  "Cond_FirstUseEver", "Key_Escape", "MouseButton_Left", "WindowFlags_NoCollapse",
}

--- The layout's semantic colours, resolved to ReaImGui's 0xRRGGBBAA.
---
--- Note the byte order differs from `adapter.lice`, which wants ARGB. Same two
--- colours, two backends, one definition each.
local COLOURS = {
  ink = 0x000000FF,
  paper = 0xFFFFFFFF,
}

--- The window's initial size, and the smallest grid worth drawing.
local WINDOW_W, WINDOW_H = 380, 470
local MIN_GRID = 120

--- Room under the grid for the button row.
local FOOTER = 34

--------------------------------------------------------------------------------
-- Binding
--------------------------------------------------------------------------------

--- Does every name this backend uses exist on `api`?
---
--- The versioned shim raises on an unknown field rather than answering nil, so
--- the read is guarded. Either way a name this file got wrong is reported by
--- name here instead of failing mid-frame with the window already on screen.
--- @param api table
--- @param names string[]
--- @return string|nil missing
local function absent(api, names)
  for _, name in ipairs(names) do
    local ok, value = pcall(function() return api[name] end)
    if not ok or value == nil then
      return name
    end
  end
  return nil
end

--- The ReaImGui 0.9-and-later binding: ask the extension where its shim lives,
--- then require the API version this backend was written against.
---
--- `ImGui_GetBuiltinPath` arrived with the shim in 0.9, so its presence is the
--- test for whether this style is available at all.
---
--- The builtin path is PREPENDED to `package.path` rather than replacing it —
--- the upstream one-liner assigns over `package.path`, which here would throw
--- away the entry script's own module roots and break every later require.
--- @return table|nil api
--- @return string|nil err
local function versioned()
  if not reaper.APIExists("ImGui_GetBuiltinPath") then
    return nil, nil
  end
  local root = reaper.ImGui_GetBuiltinPath()
  if not root or root == "" then
    return nil, "ReaImGui did not say where its Lua shim is installed."
  end
  package.path = root .. "/?.lua;" .. package.path

  local loaded, loader = pcall(require, "imgui")
  if not loaded then
    return nil, "ReaImGui's shim could not be loaded: " .. tostring(loader)
  end
  local built, api = pcall(loader, M.API_VERSION)
  if not built then
    return nil, string.format("ReaImGui cannot provide API version %s: %s",
      M.API_VERSION, tostring(api))
  end
  return api, nil
end

--- The pre-0.9 binding: the flat `reaper.ImGui_*` namespace.
---
--- Kept because an install that predates the shim has no other way in, and a
--- window that never opens is the worst failure this slice can have. Constants
--- are getters in this style, so they are called once here and stored as values
--- — which is exactly the shape the versioned API already has.
--- @return table|nil api
--- @return string|nil err
local function flat()
  if not reaper.APIExists("ImGui_CreateContext") then
    return nil, nil
  end
  local api = {}
  for _, name in ipairs(FUNCTIONS) do
    api[name] = reaper["ImGui_" .. name]
  end
  for _, name in ipairs(CONSTANTS) do
    local getter = reaper["ImGui_" .. name]
    if type(getter) == "function" then
      local ok, value = pcall(getter)
      api[name] = ok and value or nil
    end
  end
  return api, nil
end

--- The resolved binding, or a message naming what is missing.
---
--- Resolved once and remembered: `package.path` is edited on the way through,
--- and the shim's own `require` should happen once per action either way.
--- @return table|nil api
--- @return string|nil err
local resolved, resolveError
function M.binding()
  if resolved then
    return resolved, nil
  end
  if resolveError then
    return nil, resolveError
  end

  local api, err = versioned()
  if not api and not err then
    api, err = flat()
  end
  if not api then
    resolveError = err or
      "This action needs ReaImGui.\n\nInstall it through ReaPack " ..
      "(Extensions > ReaPack > Browse packages), then restart REAPER."
    return nil, resolveError
  end

  local missing = absent(api, FUNCTIONS) or absent(api, CONSTANTS)
  if missing then
    resolveError = string.format(
      "This version of ReaImGui does not provide %s, which the chord grid needs."
      .. "\n\nUpdate ReaImGui through ReaPack and restart REAPER.", missing)
    return nil, resolveError
  end

  resolved = api
  return resolved, nil
end

--------------------------------------------------------------------------------
-- Painting
--------------------------------------------------------------------------------

--- @param colour string|nil
local function rgba(colour)
  return COLOURS[colour or "ink"] or COLOURS.ink
end

--- Paint one layout primitive into the window's draw list.
---
--- `at` carries the grid's top-left corner in screen coordinates and the same
--- three scale factors `adapter.lice` uses: x by width, y by height, scalars by
--- the smaller of the two.
--- @class Surface
--- @field ImGui table
--- @field ctx userdata
--- @field dl userdata
--- @field ox number left edge of the grid, in screen coordinates
--- @field oy number top edge of the grid, in screen coordinates
--- @field w number
--- @field h number
--- @field s number

--- @param at Surface
local function paint(at, p)
  local ImGui = at.ImGui
  local colour = rgba(p.colour)

  if p.kind == "line" then
    ImGui.DrawList_AddLine(at.dl,
      at.ox + p.x1 * at.w, at.oy + p.y1 * at.h,
      at.ox + p.x2 * at.w, at.oy + p.y2 * at.h,
      colour, math.max(1, p.thickness * at.s))
  elseif p.kind == "rect" then
    ImGui.DrawList_AddRectFilled(at.dl,
      at.ox + p.x * at.w, at.oy + p.y * at.h,
      at.ox + (p.x + p.w) * at.w, at.oy + (p.y + p.h) * at.h, colour)
  elseif p.kind == "circle" then
    local cx, cy = at.ox + p.cx * at.w, at.oy + p.cy * at.h
    if p.filled then
      ImGui.DrawList_AddCircleFilled(at.dl, cx, cy, p.r * at.s, colour)
    else
      ImGui.DrawList_AddCircle(at.dl, cx, cy, p.r * at.s, colour, 0,
        math.max(1, (p.thickness or 0) * at.s))
    end
  elseif p.kind == "text" then
    -- The layout gives a box and an alignment. ImGui's draw list places text by
    -- its top-left corner, so the box is honoured by measuring the string and
    -- centring it. The SIZE in the primitive is not honoured: sizing text needs
    -- a font object attached to the context, and how that is done changed
    -- between ReaImGui versions. The window uses its own font at its own size,
    -- so the title reads smaller here than in the exported PNG.
    local tw, th = ImGui.CalcTextSize(at.ctx, p.text)
    local x, y = at.ox + p.x * at.w, at.oy + p.y * at.h
    if p.align == "centre" then
      x = x + (p.w * at.w - tw) / 2
      y = y + (p.h * at.h - th) / 2
    end
    ImGui.DrawList_AddText(at.dl, x, y, colour, p.text)
  end
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

--- Draw the grid for the current voicing and act on a click in it.
---
--- The geometry is entirely `core.layout`'s: this function decides how big a
--- square to give it and where on screen that square starts, and nothing else.
--- The hit test is `layout.cellAt` on the same computed layout that was just
--- painted, so a click lands on what is displayed by construction.
--- @param ImGui table
--- @param ctx userdata
--- @param state { voicing: Voicing }
local function grid(ImGui, ctx, state)
  local availW, availH = ImGui.GetContentRegionAvail(ctx)
  local size = math.max(MIN_GRID, math.min(availW, availH - FOOTER))
  local ox, oy = ImGui.GetCursorScreenPos(ctx)

  local computed = layout.compute(state.voicing, size, size)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- The diagram is ink on paper in the PNG, so it is ink on paper here too,
  -- whatever colour the user's ImGui theme paints the window behind it. Without
  -- this the grid is invisible on a dark theme and, worse, would not be the
  -- picture the user is about to get.
  ImGui.DrawList_AddRectFilled(dl, ox, oy, ox + size, oy + size, COLOURS.paper)

  local at = { ImGui = ImGui, ctx = ctx, dl = dl, ox = ox, oy = oy,
    w = size, h = size, s = size }
  for _, p in ipairs(computed.primitives) do
    paint(at, p)
  end

  -- Claimed after painting so the click region covers exactly the square that
  -- was drawn, and so the cursor moves past it for the button row below.
  ImGui.InvisibleButton(ctx, "##grid", size, size)
  if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then
    local mx, my = ImGui.GetMousePos(ctx)
    local index, fret = layout.cellAt(computed, mx - ox, my - oy)
    if index then
      state.voicing = voicing.toggleFret(state.voicing, index, fret)
    end
  end
end

--- Open the chord grid on a voicing.
---
--- ONE-SHOT, per the PRD's interaction model: the window opens on the item that
--- was selected when the action ran, and the first of Apply, Cancel or Escape
--- ends it. Nothing watches the selection and no state outlives the window —
--- when the loop stops deferring, the context goes with it.
---
--- `onApply` is handed the edited voicing and is the only path that writes
--- anything. Backing out calls nothing at all, which is what makes "the item is
--- unchanged" true rather than a promise: `core.voicing` never edits in place,
--- so the voicing read off the item is still the one on the item.
--- @param opts { title: string, voicing: Voicing, onApply: fun(v: Voicing) }
--- @return boolean ok
--- @return string|nil err
function M.open(opts)
  local ImGui, err = M.binding()
  if not ImGui then
    return false, err
  end

  local state = { voicing = opts.voicing }
  local ctx = ImGui.CreateContext(opts.title)

  local function frame()
    ImGui.SetNextWindowSize(ctx, WINDOW_W, WINDOW_H, ImGui.Cond_FirstUseEver)
    local visible, stillOpen = ImGui.Begin(ctx, opts.title, true,
      ImGui.WindowFlags_NoCollapse)

    -- Begin also answers false for a window that is merely clipped rather than
    -- closed, and only the SECOND return says the user asked to close. Anything
    -- other than an explicit false keeps the loop alive: a window that vanished
    -- because it was scrolled out of view would take the user's edit with it.
    if stillOpen == nil then
      stillOpen = true
    end

    local applied = false
    if visible then
      grid(ImGui, ctx, state)
      applied = ImGui.Button(ctx, "Apply")
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel") then
        stillOpen = false
      end
      -- ReaImGui's Begin closes the window itself when it returns false, so End
      -- is called only when it returned true. This is the opposite of Dear
      -- ImGui's own rule and is easy to "fix" into a crash.
      ImGui.End(ctx)
    end

    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
      stillOpen = false
    end

    if applied then
      opts.onApply(state.voicing)
    elseif stillOpen then
      reaper.defer(frame)
    end
  end

  reaper.defer(frame)
  return true
end

return M
