--- The ImGui rendering backend: layout primitives to screen, plus input.
---
--- This module draws nothing of its own. It receives a primitive list from
--- `core.layout` and paints it, exactly as `adapter.lice` paints the same list
--- into a PNG. That shared definition is what guarantees the grid the user
--- clicks and the image they get cannot drift apart.
---
--- The window's fields hold no chord logic either. Typing goes through
--- `voicing.parse`, a name through `voicing.setName`, a framing through
--- `voicing.canFrame` and `voicing.setBaseFret`; none of those rules is
--- reimplemented here, and every one of them returns a NEW voicing, which is
--- what keeps Cancel structurally safe.
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
  "Button", "InvisibleButton", "IsItemClicked", "IsItemActive",
  "GetMousePos", "IsKeyPressed",
  "InputText", "InputInt", "IsAnyItemActive",
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
---
--- Taller than the grid alone needs: three rows of controls sit above it.
local WINDOW_W, WINDOW_H = 380, 560
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

--- The window's editable state.
---
--- `voicing` is the value; `text` is the chord string as the user currently has
--- it written. Two representations of one thing, which is the whole difficulty
--- of this window — see `chordField`.
--- `drag` is the gesture in progress on the grid, if the mouse is down on it.
--- @class GridState
--- @field voicing Voicing
--- @field text string
--- @field drag { fret: integer, from: integer, to: integer }|nil

--- The free-text name, which is drawn on the diagram and names the item.
---
--- Unlike the chord string, the name needs no buffer of its own: it is stored
--- verbatim and read straight back, so there is no normalisation to fight the
--- cursor with. Routing it through `voicing.setName` rather than `voicing.parse`
--- is deliberate — a rename must not depend on the chord field next to it being
--- parseable at that instant, and half-typed chord strings are normal.
--- @param ImGui table
--- @param ctx userdata
--- @param state GridState
local function nameField(ImGui, ctx, state)
  local edited, typed = ImGui.InputText(ctx, "Name###name", state.voicing.name or "")
  if edited then
    state.voicing = voicing.setName(state.voicing, typed)
  end
end

--- The chord string, synced with the grid.
---
--- THE FIELD AND THE VOICING ARE TWO WRITINGS OF ONE VALUE, and keeping them in
--- step is where an app like this normally breaks. Rewrite the field from the
--- voicing every frame and it fights the cursor and eats half-typed characters;
--- never rewrite it and the grid stops saying what the user built.
---
--- THE RULE IS ABOUT WHEN, NOT ABOUT WHICH IS MASTER:
---
---   * WHILE THE USER IS TYPING, THE FIELD IS AUTHORITATIVE. Its contents are
---     what they typed, character for character, and are never normalised back
---     at them mid-word — so `x-3-2-0-1-0` is not rewritten to `x32010` under
---     the cursor, even though the two mean the same chord.
---   * WHEN THE VOICING MOVES BY ANY OTHER MEANS — a click on the grid — THE
---     VOICING IS AUTHORITATIVE, and the field is rewritten from it. That
---     rewrite lives in `grid`, at the one place a click changes the shape.
---
--- The field is therefore written from the voicing only on frames the user was
--- not typing into it, and those two cases cannot both happen in one frame.
---
--- Every keystroke is parsed, and a parse that fails is DISCARDED IN SILENCE:
--- half-typed input is the ordinary state of a field somebody is typing into,
--- not an error to report, so the diagram simply goes on showing the last shape
--- that was real. `voicing.parse` merges into the voicing being edited, so a
--- barre — which no chord string can express — survives being retyped.
--- @param ImGui table
--- @param ctx userdata
--- @param state GridState
local function chordField(ImGui, ctx, state)
  local edited, typed = ImGui.InputText(ctx, "Chord###chord", state.text)
  if edited then
    state.text = typed
    local parsed = voicing.parse(typed, nil, state.voicing)
    if parsed then
      state.voicing = parsed
    end
  end
end

--- The fret the top of the grid sits at: derived, unless the user says
--- otherwise.
---
--- The field always shows the framing IN FORCE — `voicing.baseFret` answers the
--- derived value until there is an override and the override afterwards — so
--- there is one number on screen rather than a derived one and a box that
--- disagrees with it. The label says which of the two the user is looking at.
---
--- A value that cannot hold the shape is not offered: `voicing.canFrame` is
--- asked first, and a refusal leaves the voicing alone, so the field snaps back
--- rather than reframing the diagram somewhere the dots would not be visible.
--- That question is asked of `core.voicing` and never answered here — a second
--- copy of the five-fret rule in the UI is how the two drift apart.
---
--- The button is the way back to derived framing. Slice 004 drops an override
--- that has stopped framing the chord, but until now there was no way to change
--- one's mind about one that still works.
--- @param ImGui table
--- @param ctx userdata
--- @param state GridState
local function baseFretField(ImGui, ctx, state)
  -- Whether the box is showing the user's number or the derived one is decided
  -- by the SAME question that decides whether the diagram obeys it. A stored
  -- override that has stopped framing its chord is ignored by `voicing.baseFret`
  -- and must therefore not be labelled as the user's choice here either.
  local mine = voicing.canFrame(state.voicing.frets, state.voicing.baseFret)
  local label = mine and "First fret (yours)###base" or "First fret (auto)###base"

  local edited, chosen = ImGui.InputInt(ctx, label, voicing.baseFret(state.voicing), 1, 1)
  if edited and voicing.canFrame(state.voicing.frets, chosen) then
    state.voicing = voicing.setBaseFret(state.voicing, chosen)
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Auto") then
    state.voicing = voicing.setBaseFret(state.voicing, nil)
  end
end

--- Draw the grid for the current voicing and act on a click in it.
---
--- The geometry is entirely `core.layout`'s: this function decides how big a
--- square to give it and where on screen that square starts, and nothing else.
--- The hit test is `layout.cellAt` on the same computed layout that was just
--- painted, so a click lands on what is displayed by construction.
--- @param ImGui table
--- @param ctx userdata
--- @param state GridState
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

  -- Every query below is about the button just claimed, so nothing may be drawn
  -- between there and here.
  local mx, my = ImGui.GetMousePos(ctx)
  local index, fret = layout.cellAt(computed, mx - ox, my - oy)

  -- WHERE THE LINE BETWEEN A CLICK AND A DRAG SITS.
  --
  -- Both gestures open with the mouse going down on a cell, so they can only be
  -- told apart by what happens next, and the test has to be one that neither
  -- gesture can fail by accident. It is this: DID THE POINTER END ON A
  -- DIFFERENT STRING FROM THE ONE IT STARTED ON, AT THE SAME FRET?
  --
  --   * Ended where it began — a CLICK, dispatched to `voicing.toggleFret`
  --     exactly as in slice 006. Vertical wander does not matter: a click that
  --     slides up or down its own string is still a click on the string it
  --     started on, so a shaky hand cannot turn one into a barre.
  --   * Ended on another string of the same fret row — a DRAG, and the barre
  --     spans from the string it started on to the string it ended on.
  --
  -- The fret is taken from the cell the drag STARTED in and never moves after
  -- that; wandering into another row leaves the span where it was rather than
  -- redrawing the bar at whichever row the pointer happened to end in. A drag
  -- released off the grid keeps the last cell it saw, for the same reason.
  --
  -- The residual risk is a click landing near the midpoint between two strings
  -- and wobbling across the boundary, which would draw a two-string bar nobody
  -- asked for. `layout.cellAt` snaps to the nearest string, so that needs a
  -- press about half a string gap off centre; the bar is visible immediately
  -- and one click takes it away. THIS IS THE ONE INTERACTION IN THE PROJECT
  -- THAT CANNOT BE CHECKED WITHOUT REAPER — if it misfires in practice, the fix
  -- is a minimum travel in pixels before a drag counts, and it belongs here.
  if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then
    state.drag = index and { fret = fret, from = index, to = index } or nil
  elseif state.drag and ImGui.IsItemActive(ctx) then
    if index and fret == state.drag.fret then
      state.drag.to = index
    end
  end

  -- The mouse has come up: the button is no longer active and whatever the drag
  -- collected is now the gesture.
  if state.drag and not ImGui.IsItemActive(ctx) then
    local drag = state.drag
    state.drag = nil

    if drag.to == drag.from then
      state.voicing = voicing.toggleFret(state.voicing, drag.from, drag.fret)
      -- THE ONE PLACE THE FIELD IS WRITTEN FROM THE VOICING. The user was
      -- clicking, not typing, so there is no cursor to disturb and no
      -- half-finished word to normalise — and this is how a shape built by
      -- hand teaches its owner the chord string for it. See `chordField`.
      state.text = voicing.toText(state.voicing)
    elseif drag.fret > voicing.OPEN then
      -- A barre moves no finger, so the chord string is unchanged and the field
      -- is deliberately NOT rewritten: there is nothing new for it to say, and
      -- rewriting it would normalise text the user typed for no reason. A drag
      -- across the row above the nut falls through here and does nothing —
      -- there are no barres above the nut, and toggling several strings on a
      -- gesture nobody defined would be inventing one.
      state.voicing = voicing.setBarre(state.voicing, drag.fret, drag.from, drag.to)
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
---
--- The voicing that comes back carries the name, the shape and any framing the
--- user chose, so `onApply` needs nothing else from the window. Everything the
--- three fields do is an edit on that one value.
--- @param opts { title: string, voicing: Voicing, onApply: fun(v: Voicing) }
--- @return boolean ok
--- @return string|nil err
function M.open(opts)
  local ImGui, err = M.binding()
  if not ImGui then
    return false, err
  end

  local state = {
    voicing = opts.voicing,
    text = voicing.toText(opts.voicing),
  }
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
      -- The fields go above the grid, so the space the grid is given is what
      -- they have left over: `grid` asks for the content region at its own
      -- cursor position and sizes itself to fit.
      nameField(ImGui, ctx, state)
      chordField(ImGui, ctx, state)
      baseFretField(ImGui, ctx, state)
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

    -- Escape closes the window, EXCEPT while a field has the keyboard. In a
    -- text field Escape means "undo what I just typed", and a user reaching for
    -- that must not lose the whole chord instead. Now that the window has
    -- fields, the unguarded check would do exactly that.
    if not ImGui.IsAnyItemActive(ctx)
      and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
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
