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

- [x] An action renders a hardcoded voicing to a PNG written into a project subfolder
- [x] The image attaches to the selected empty item and displays in the arrange view
- [x] Selecting several empty items renders the display-flag variants side by side, so the correct
      one is chosen by looking rather than by iterating
- [x] Resizing an item scales the image, and the diagram's aspect ratio is not distorted
- [x] The diagram is legible when the item is dragged tall
- [x] The script prints a step-by-step report to the console, naming any step that failed
- [x] The report states whether text rendering worked, separately from shape rendering
- [x] The chosen display flag value is recorded in the repo for later slices — D21/D22 in the brief,
      and carried into `issues/003-typed-chord-to-diagram.md`
- [x] A written finding records whether LICE rendering is viable, or what the fallback must be
- [x] The script carries ReaPack metadata and the repository index is generated and committed
- [ ] The tester installs it via ReaPack on Windows and runs the action successfully — **instructions
      sent; confirmation outstanding.** Not blocking: the same script was already run successfully
      from a manual download, so only the delivery mechanism is unconfirmed.
- [x] The image reference resolves from a path relative to the project

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

## Findings — runs 2 to 4: the display flag (O2 resolved)

**Settled: `IMGRESOURCEFLAGS = 3` on a square 1024×1024 canvas.** Confirmed by the tester as good at
all usable item sizes.

Getting there took three runs, and the reasoning is worth keeping:

- **Run 2** ruled out padding. Flag 1 kept proportions but tiled into repeats; flag 5 tiled and
  cropped the title; flag 3 never repeated but distorted. Widening the canvas with white padding did
  not stop the tiling.
- **Run 3** found the more serious defect: **grid lines vanished at practical item sizes on every
  variant.** This is a downscaling artefact, not a resolution shortfall — see D22 in the brief. Fixed
  by making stroke weight proportional to canvas size.
- **Run 4** swept the whole `IMGRESOURCEFLAGS` bitfield, including the undocumented values 2, 4, 6
  and 7, since only 1, 3 and 5 are documented and the requirement was "fit, never repeat". With the
  square power-of-two canvas and heavier strokes, **flag 3 became a clear winner** — it is the only
  value that never repeats, and at 1024×1024 with generous internal margins its stretching is not
  objectionable.

Also fixed in run 4: extra clearance between the chord name and the diagram, which had been slightly
crossing over.

**Both open technical questions in this slice are now closed.** What remains is ReaPack delivery.

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
