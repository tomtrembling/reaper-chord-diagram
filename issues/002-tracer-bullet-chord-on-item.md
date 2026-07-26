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

## Constraint: no local verification

REAPER is not installed on the development machine — see *Who it's for* in the parent PRD. There is
no "try it locally first" step; every run happens on the tester's Windows machine. The script must
therefore be built to answer everything in **one** run:

- it reports each step to the REAPER console — dependency present, bitmap created, font created,
  PNG written and where, chunk updated — so a failure names itself instead of being silent
- every uncertain choice is a switch at the top of the file, so the tester can try variants without
  waiting for a new build
- visual alternatives render side by side rather than one per round trip

## Acceptance criteria

- [ ] An action renders a hardcoded voicing to a PNG written into a project subfolder
- [ ] The image attaches to the selected empty item and displays in the arrange view
- [ ] Selecting several empty items renders the display-flag variants side by side, so the correct
      one is chosen by looking rather than by iterating
- [ ] Resizing an item scales the image, and the diagram's aspect ratio is not distorted
- [ ] The diagram is legible when the item is dragged tall
- [ ] The script prints a step-by-step report to the console, naming any step that failed
- [ ] The report states whether text rendering worked, separately from shape rendering
- [ ] The chosen display flag value is recorded in the repo for later slices
- [ ] A written finding records whether LICE rendering is viable, or what the fallback must be
- [ ] The script carries ReaPack metadata and the repository index is generated and committed
- [ ] The tester installs it via ReaPack on Windows and runs the action successfully
- [ ] The image reference resolves from a path relative to the project

## Findings — run 1 (REAPER 7.78/x64, Win64)

**The rendering chain works end to end.** Every stage reported ok on the first run:

- `JS_LICE_*` bitmap creation, shape drawing and `JS_LICE_WritePNG` all succeeded, so **O1 is
  resolved** — LICE rendering is viable and the external-renderer fallback is not needed. The
  argument orders used were correct, despite being unverifiable from any online source.
- **Text rendering worked**, via `JS_GDI_CreateFont` + `JS_LICE_SetFontFromGDI` + `JS_LICE_DrawText`
  with Arial. This was the most platform-sensitive part of the plan.
- The state chunk write succeeded on all three items, using the `RESOURCEFN` + `IMGRESOURCEFLAGS`
  block inserted before the chunk's closing `>`.
- The image path stored **relative** to the project (`chord-diagrams\spike-Cadd9.png`) and resolved
  correctly, confirming project portability.

Consequently **risk 1 in the parent PRD is retired**: the plan holds as written, and no fallback
renderer is required.

Still open: which display flag frames the diagram correctly (**O2**), pending visual review.

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
