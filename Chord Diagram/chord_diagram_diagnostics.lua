--[[
@description Chord Diagram: copy diagnostics
@version 0.15.0
@author Tom Trembling
@noindex
@about
  Copies a plain-text report about the Chord Diagram plugin to the clipboard, so
  a problem can be reported without being walked through it.

  The report says which versions of REAPER, ReaImGui and js_ReaScriptAPI are
  installed, where the plugin resolved its files to, what is selected, and the
  last error the plugin showed. Paste it into a message.

  It is also printed to the ReaScript console, so the text is available even on
  a machine where nothing can reach the clipboard.

  Nothing is changed by running this.
@changelog
  0.15.0 No change; released alongside Chord Diagram 0.15.0.
  0.14.0 No change; released alongside Chord Diagram 0.14.0.
  0.13.0 No change; released alongside Chord Diagram 0.13.0.
  0.12.0 First release, alongside Chord Diagram 0.12.0.
--]]

--------------------------------------------------------------------------------
-- Why @noindex
--
-- This action ships as part of the Chord Diagram package, listed in that
-- script's `@provides` as an additional `[main]` file. `reapack-index` treats
-- any file carrying a `@version` tag as a package in its own right, and a file
-- that is BOTH its own package and provided by another is a conflict — one the
-- indexer reports as a warning and then resolves by silently dropping the whole
-- Chord Diagram package from the index. `@noindex` says "not a package", which
-- leaves the version and changelog above readable by a human without them
-- meaning anything to ReaPack.
--
-- `@version` stays because `spec/header_version_spec.lua` asserts every shipped
-- action agrees with `core.version.CURRENT`, and the diagnostics report is the
-- place a wrong version would do the most damage.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Module loading
--
-- The same bootstrap as `chord_diagram.lua`, and deliberately a COPY rather
-- than something shared: a module that finds the modules has to be found first,
-- and this action's whole job is to still work on an installation where the
-- other one does not.
--------------------------------------------------------------------------------

local SEP = package.config:sub(1, 1)
local scriptPath = select(2, reaper.get_action_context())
local scriptDir = scriptPath:match("^(.*)[/\\][^/\\]*$") or "."

for _, root in ipairs({
  scriptDir .. SEP .. "src",
  scriptDir .. SEP .. ".." .. SEP .. "src",
}) do
  package.path = table.concat({
    root .. SEP .. "?.lua",
    root .. SEP .. "?" .. SEP .. "init.lua",
    package.path,
  }, ";")
end

local diagnostics = require("core.diagnostics")
local preflight = require("core.preflight")
local version = require("core.version")

local clipboard = require("adapter.clipboard")
local console = require("adapter.console")
local deps = require("adapter.deps")
local dialog = require("adapter.dialog")
local errors = require("adapter.errors")
local imgui = require("adapter.imgui")
local itemAdapter = require("adapter.item")
local project = require("adapter.project")

local TITLE = "Chord Diagram diagnostics"

--------------------------------------------------------------------------------
-- Gathering
--
-- Every question below is one a failure on the tester's machine has already
-- raised and could not be answered from macOS. Nothing here judges anything:
-- the report states what was found and lets the reader draw the conclusion,
-- because a diagnostic that decides what went wrong can only ever be as right
-- as the guess behind it.
--------------------------------------------------------------------------------

--- What ReaImGui turned out to be, in the terms that tell its failures apart.
local function reaImGui()
  local about = imgui.describe()

  if not about.installed then
    return { name = "ReaImGui", version = nil, minimum = about.requested },
      about.error
  end

  local note = (about.style or "no binding resolved")
    .. " binding, API " .. about.requested .. " requested"
  if about.dearImGui then
    note = note .. ", Dear ImGui " .. about.dearImGui
  end

  return {
    name = "ReaImGui",
    version = about.version or "installed, version unknown",
    -- Compared against the floor only when there is a real version to compare.
    -- An install too old to say what it is would otherwise read as zero and be
    -- flagged as too old, which might be true but would not have been checked.
    minimum = about.version and about.requested or nil,
    note = note,
  }, about.error
end

local imguiComponent, imguiError = reaImGui()

local projectDir = project.dir()
local items, selected = itemAdapter.selectedEmptyItems()

--- What the chord action would do if it were run right now.
---
--- ASKED OF `core.preflight`, THE SAME FUNCTION THE ACTION ITSELF ASKS, so the
--- report cannot say the action would run while the action refuses. It also
--- turns the commonest complaint — "I press the key and nothing happens" — into
--- a line of the report, since the answer is usually a refusal the user
--- dismissed without reading.
local refusal = preflight.refusal({
  host = deps.hostVersion(),
  missing = deps.missing(),
  unusable = deps.unusable(),
  projectSaved = projectDir ~= nil,
  selected = selected,
  empty = #items,
})

--- Where a module actually resolved to.
---
--- The entry scripts put TWO candidate roots on the path so the plugin runs
--- whether ReaPack installed `src/` beside the script or one level up. Which of
--- them won is otherwise unknowable, and "the modules were not found" is the
--- failure a packaging change causes.
--- @param name string
--- @return string|nil
local function resolvedModule(name)
  local ok, path = pcall(package.searchpath, name, package.path)
  return ok and path or nil
end

local facts = {
  components = {
    { name = "Chord Diagram", version = version.CURRENT },
    { name = "REAPER", version = deps.hostVersion(), minimum = version.MIN_REAPER },
    { name = "js_ReaScriptAPI",
      version = deps.installed("js_ReaScriptAPI")
        and (deps.version("js_ReaScriptAPI") or "installed, version unknown")
        or nil },
    imguiComponent,
    { name = "Lua", version = _VERSION },
  },

  paths = {
    { label = "Action", value = scriptPath },
    { label = "Modules", value = resolvedModule("core.version") },
    { label = "ReaImGui shim", value = resolvedModule("imgui") },
    { label = "Project", value = projectDir or "not saved" },
    { label = "Diagrams", value = projectDir
      and project.absoluteImagePath(projectDir, ""):gsub("[/\\]$", "") or nil },
  },

  state = {
    { label = "Would run now", value = refusal
      and ("no -- " .. diagnostics.oneLine(refusal)) or "yes" },
    { label = "Items selected", value = tostring(selected) },
    { label = "Of those, empty", value = tostring(#items) },
    { label = "Chord on item", value = (#items == 1)
      and (itemAdapter.storedVoicing(items[1]) or "none stored") or "n/a" },
    { label = "Diagrams on disk", value = projectDir
      and tostring(project.imageCount(projectDir) or "folder unreadable") or "n/a" },
    -- The window failing to open is the failure this project can least afford,
    -- and the message naming its cause is the whole content of the slice 006
    -- symptom table. It goes in the report whether or not the user saw it.
    -- Flattened, because the message is written to be read in a message box
    -- over three lines and this is a report whose values are one line each.
    { label = "Window", value = imguiError and diagnostics.oneLine(imguiError)
      or "binding resolved" },
  },

  lastError = errors.last(),
}

--------------------------------------------------------------------------------
-- Reporting
--
-- The console first, ALWAYS, and the clipboard after. The console cannot fail
-- and needs no extension, so the text exists somewhere the user can select it
-- before anything is attempted that might not work. The alert then says which
-- of the two they have — being told "copied" when nothing was copied is worse
-- than being told to look in the console.
--------------------------------------------------------------------------------

local text = diagnostics.report(facts)

console.log("\n" .. text)

if clipboard.copy(text) then
  dialog.alert(TITLE, "The diagnostic report is on your clipboard.\n\nPaste it "
    .. "into your message. It is also in the ReaScript console.")
else
  dialog.alert(TITLE, "The report could not be put on the clipboard, so it has "
    .. "been printed to the ReaScript console instead.\n\nOpen Actions > Show "
    .. "console output, select the text and copy it.")
end
