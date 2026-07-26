# 002 — Tracer bullet: hardcoded chord on an item, delivered to Windows

## Type

HITL — requires human judgement on rendered image quality, and confirmation by the Windows tester.

## Parent PRD

`issues/prd.md`

## What to build

The thinnest possible complete path, with no UI at all: one action that renders a **hardcoded**
voicing to a PNG, saves it into a project subfolder, and attaches it to the selected empty item so
it displays in the arrange view. Then ship that action to the Windows tester through ReaPack and
confirm it works there.

This slice exists to answer the two unresolved technical questions in the parent PRD's *Further
Notes* before any code is built on top of them: whether the LICE functions can produce an
acceptable-quality diagram from Lua, and which image display flag frames a portrait diagram
correctly rather than distorting it. It also proves the delivery pipeline and the cross-platform
assumption at the point where they are cheapest to change.

No parsing, no layout module, no UI — draw something crude if necessary. The goal is evidence, not
elegance.

## Acceptance criteria

- [ ] An action renders a hardcoded voicing to a PNG written into a project subfolder
- [ ] The image attaches to the selected empty item and displays in the arrange view
- [ ] Resizing the item scales the image, and the diagram's aspect ratio is not distorted
- [ ] The diagram is legible when the item is dragged tall
- [ ] The chosen image display flag value is recorded in the repo for later slices
- [ ] A written finding records whether LICE rendering is viable, or what the fallback must be
- [ ] The script carries ReaPack metadata and the repository index is generated and committed
- [ ] The tester installs it via ReaPack on Windows and runs the action successfully
- [ ] A project created on macOS opens on Windows with its diagram still rendering, confirming the
      image reference is stored relative to the project

## Blocked by

- Blocked by `issues/001-dev-infrastructure.md`

## User stories addressed

- User story 16
- User story 17
- User story 19
- User story 26
- User story 27
- User story 38
- User story 39
- User story 40
- User story 45
- User story 46
