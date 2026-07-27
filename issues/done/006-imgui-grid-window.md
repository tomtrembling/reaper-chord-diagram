# 006 — ImGui window with an interactive grid

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Replace the native input dialog with the real UI: a window containing a fretboard grid that the
user clicks to build a shape.

The grid is drawn by the ImGui backend from the **same layout primitives** the image renderer uses,
so what the user sees matches what gets exported. Hit-testing reuses those same coordinates, which
is what guarantees a click lands on the cell it appears to land on.

Window lifecycle is one-shot, per *Interaction model* in the parent PRD: select item, hotkey, edit,
Apply, closed. No selection watching and no background state.

## Acceptance criteria

- [x] The window opens with a grid drawn from the shared layout primitives
- [x] Clicking a cell places a dot; clicking it again clears it
- [x] Strings can be toggled between open and muted above the nut
- [x] The on-screen grid visibly matches the diagram that gets exported
- [x] Apply writes the chord to the item and closes the window
- [x] Cancel, and the Escape key, close the window leaving the item unchanged
- [x] The window becomes the primary entry path, replacing the native dialog
- [x] Specs: hit-testing round-trips — a coordinate generated for a given string and fret maps back
      to that same string and fret

## Blocked by

- Blocked by `issues/003-typed-chord-to-diagram.md`
- Blocked by `issues/005-persistence-and-round-trip.md`

## User stories addressed

- User story 4
- User story 13
- User story 14
- User story 15

## What was built

A window with a clickable fretboard grid, replacing the native input dialog as the entry path.

`src/adapter/imgui.lua` is the new backend and the **only** module in the project that knows how
ReaImGui is reached. ReaImGui changed its entry point at 0.9 — a script now asks the extension for
its Lua shim directory and requires a numbered API version — while older installs expose the flat
`reaper.ImGui_*` namespace with constants as getters rather than values. Both are resolved behind
one table, chosen by whether `ImGui_GetBuiltinPath` exists, and every ReaImGui name the backend uses
is listed and checked at load time so a wrong name reports itself instead of failing mid-frame.
Nothing outside that module can tell which style won.

The grid is painted from `core.layout`'s primitives, the same list `adapter.lice` paints into the
PNG, on an opaque paper-coloured square so the preview is the picture the user is about to get
whatever their ImGui theme is. Clicks are dispatched through `layout.cellAt` on the same computed
layout that was just painted, so a click lands on what is displayed by construction.

`core.voicing` gained `setFret` (named by the PRD; this slice is its first caller) and `toggleFret`,
which holds the click rule: a grid cell places a dot and clicking it again clears the string to
muted; the row above the nut toggles open against muted and rings a fretted string open. Two
gestures reach all three states a string can be in, and nothing is ever inferred. `layout.cellAt`
was extended so that row reports `MUTED` or `OPEN` according to what is drawn there, which makes the
round trip total: every marker the diagram draws — dot, ring or cross — maps back to the string and
position it was drawn for.

Lifecycle is one-shot: the item's chunk is read before the window opens, the frame loop runs on
`reaper.defer`, and Apply, Cancel or Escape ends it. Cancel and Escape call nothing at all —
`core.voicing` never edits in place, so the voicing read off the item is still the one on the item.

**Not built, deliberately:** the chord text field, the name field and the base-fret override
(slice 007) and barres (slice 008). Removing the native dialog took the name with it, so until
slice 007 a new chord is titled with its own chord string via the fallback that already existed for
unnamed chords; a reopened chord keeps the name it has. That gap is recorded in the HITL queue.

**Everything ImGui-related is unverified.** REAPER is not installed on the development machine, so
`make verify` only parses `src/adapter/imgui.lua`. The core changes are specced and green. The
slice 006 section of `issues/hitl-queue.md` leads with the binding question and a symptom table for
telling the two failure modes apart.
