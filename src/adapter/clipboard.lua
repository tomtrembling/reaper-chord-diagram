--- Putting text on the system clipboard.
---
--- REAPER has no clipboard call of its own, so this goes through whichever
--- extension is present. THE ONE THING THIS MODULE MAY NOT DO IS THROW: its
--- only caller is the diagnostic action, which exists to explain failures, and
--- an action that dies while reporting a problem replaces a report the user
--- could paste with a script error they cannot. Every route is guarded and the
--- answer is a boolean; the caller prints the report to the console either way,
--- so a machine where none of these work still hands the user the text.
---
--- NONE OF THIS HAS BEEN RUN. REAPER is not installed on the development
--- machine. Both call sequences are documented, both are guarded, and the
--- console fallback is what makes being wrong survivable rather than fatal.
local M = {}

--- @param name string
--- @return boolean
local function exists(name)
  local ok, present = pcall(reaper.APIExists, name)
  return ok and present == true
end

--- SWS/S&M, if it happens to be installed. Not a dependency of this plugin —
--- it is simply the cleanest route when it is there, needing no context and no
--- window.
--- @param text string
--- @return boolean
local function viaSWS(text)
  if not exists("CF_SetClipboard") then
    return false
  end
  return pcall(reaper.CF_SetClipboard, text) and true or false
end

--- ReaImGui, which IS a dependency, so this is the route that should normally
--- carry the report.
---
--- The flat `reaper.ImGui_*` namespace is used rather than the versioned shim
--- `adapter.imgui` resolves: the shim's job is the window, and the diagnostic
--- action must be able to hand over its text on an install whose shim is the
--- very thing that is broken.
---
--- `SetClipboardText` needs a context, so one is made for it. TWO THINGS ABOUT
--- THAT ARE LOAD-BEARING and were checked against ReaImGui's published source
--- rather than assumed, because getting either wrong turns the action that
--- explains failures into one that fails:
---
---   * It has no frame guard, unlike most of the API — it validates the context
---     and uses it. So calling it outside a frame is legal, which is the only
---     way this action can work: it never opens a window.
---   * A context stays valid only while it is used in each defer cycle, so one
---     that never enters a frame is disposed of on its own. There is nothing to
---     destroy and no leak to apologise for.
---
--- The write is then READ BACK, because `SetClipboardText` returns nothing and
--- the alert this feeds tells the user their report is on the clipboard. A
--- claim that cannot be checked should not be made; where it can, it is.
--- @param text string
--- @return boolean
local function viaImGui(text)
  if not exists("ImGui_SetClipboardText") or not exists("ImGui_CreateContext") then
    return false
  end
  local made, ctx = pcall(reaper.ImGui_CreateContext, "Chord Diagram diagnostics")
  if not made or not ctx then
    return false
  end
  if not pcall(reaper.ImGui_SetClipboardText, ctx, text) then
    return false
  end

  if exists("ImGui_GetClipboardText") then
    local read, back = pcall(reaper.ImGui_GetClipboardText, ctx)
    return read and back == text
  end
  return true
end

--- Put `text` on the clipboard.
--- @param text string
--- @return boolean copied
function M.copy(text)
  return viaSWS(text) or viaImGui(text)
end

return M
