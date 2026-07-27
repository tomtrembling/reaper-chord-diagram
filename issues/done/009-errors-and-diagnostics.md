# 009 — Selection validation, dependency checks and diagnostics

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Make every failure state explain itself, and give the user a way to report problems usefully.

The action requires exactly one selected empty item and must fail fast and clearly otherwise, rather
than doing nothing or silently picking an item. Required extensions are checked at startup and named
individually when missing, since they are not reliably auto-installed by the package manager.

The diagnostic action matters more than usual on this project: the developer works on macOS while
the primary user is on Windows, so a Windows-only failure cannot be reproduced directly. See
*Cross-platform* in the parent PRD.

## Acceptance criteria

- [x] Running the action with no item selected shows a clear message explaining what is needed
- [x] Running it with more than one item selected shows a clear message and modifies nothing
- [x] Running it on an item that is not an empty item shows a clear message and modifies nothing
- [x] A missing required extension produces a message naming that specific extension
- [x] Extension and host versions are checked at startup and surfaced when unsupported
- [x] A diagnostic action copies versions, resolved paths and the last error to the clipboard
- [x] Diagnostic output is plain text, suitable for pasting into a message
- [x] No failure path leaves an item partially modified

## What was built

**The decision moved out of the entry script.** `src/core/preflight.lua` is pure and takes the facts
— host version, missing extensions, an extension installed but missing a call, whether the project
is saved, how many items are selected and how many of those are empty — and answers with the message
to show or nil. Every message a user can be refused with is therefore specced, on a machine where
the code that gathers those facts can never be run. It also fixes an ordering bug: two audio items
selected used to answer "that is not an empty item", true but not the thing to fix.

The host is asked about before the extensions it would have to run, because on a REAPER too old for
ReaImGui, ReaImGui is usually absent too, and "install ReaImGui" would send the user to install
something their REAPER will not load. A host that will not report its version is allowed to run: a
reporting gap must not become a plugin that refuses to start.

**Version floors, and where they live.** `core.version` now carries `MIN_REAIMGUI = "0.9"` — a real
floor, since ReaImGui's versioned shim arrived there and `adapter.imgui` asks for it by name, which
now reads the constant instead of carrying its own copy — and `MIN_REAPER = "6.44"`, inherited from
ReaImGui's own stated host requirement rather than invented. js_ReaScriptAPI deliberately has NO
version floor: it is checked function by function against the list `adapter.lice` calls unguarded,
because that list can be read off the code where a version number would have been guessed.
`atLeast` now reads only the leading version-like prefix, so the 64 in "7.09/OSX64" is not a version
component.

**`core.version.CURRENT` was "0.1.0" while the header said 0.11.0.** Both are now 0.12.0, and
`spec/header_version_spec.lua` asserts that every action script under `Chord Diagram/` — found by
listing the directory, so a script added later is checked without anybody remembering — declares the
version `CURRENT` says. The relationship cannot be automatic across a ReaPack header and a Lua
constant, so it fails a spec instead.

**A second action**, `Chord Diagram/chord_diagram_diagnostics.lua`, with its own ReaPack header. It
prints a four-section plain-text report — Versions, Paths, State, Last error — to the console and
then copies it to the clipboard, saying which of the two happened rather than claiming a copy that
did not occur. It reports which ReaImGui binding style resolved and the message if neither did,
which is exactly the symptom table the slice 006 queue asked for, and a "Would run now" line
computed by the same `preflight.refusal` the action refuses with.

**The last error** is recorded by `src/adapter/errors.lua` into REAPER's persistent extended state,
because the action that records it and the action that reports it are different scripts. It cannot
fail: every REAPER call is wrapped, the message is flattened to one line by
`core.diagnostics.oneLine` and capped, and nothing reports whether recording worked.

**No failure path leaves an item partially modified.** `adapter.item.writeChord` owns the two writes
and their order, and puts the original chunk back if the second fails, so the item can never carry a
new diagram and an old voicing. `asUndoableEdit` wraps its work in a pcall so `Undo_EndBlock` always
runs.

None of the adapter code has been executed in REAPER. It was driven end to end against a stubbed
REAPER API on the dev machine — refusals, apply, and the rolled-back write — which catches shape
errors and nothing about signatures. `issues/hitl-queue.md` under *Slice 009* is to be worked first,
since it is what turns every other check in that file into a report.

## Blocked by

- Blocked by `issues/006-imgui-grid-window.md`

## User stories addressed

- User story 33
- User story 34
- User story 35
- User story 36
- User story 37
