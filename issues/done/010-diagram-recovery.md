# 010 — Diagram recovery

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Make missing images self-healing, cashing in the decision to store the voicing as data rather than
only as pixels.

Two behaviours: opening the editor on an item whose image file is missing rebuilds it silently, so
the user may never notice anything was wrong; and a project-wide action sweeps every item carrying
voicing data and regenerates any image that is absent, for when a whole folder has gone missing —
copied to another machine without it, or cleaned up by someone tidying "unused" files.

Both reuse the existing render path, so the added code is small.

## Acceptance criteria

- [x] Opening the editor on an item whose image file is missing rebuilds the image
- [x] The rebuilt image is re-linked to the item and displays without further user action
- [x] A project-wide action regenerates every missing diagram in the project
- [x] Deleting the entire image folder and running that action restores all diagrams
- [x] Items with no stored voicing data are skipped rather than erroring
- [x] Images that already exist are not needlessly rewritten
- [x] The action reports how many diagrams it regenerated

## Blocked by

- Blocked by `issues/005-persistence-and-round-trip.md`

## User stories addressed

- User story 29
- User story 30

## Notes on completion

Built in slice 010, version 0.13.0. The acceptance criteria are all met in code; **none of them has
been run in REAPER**, since it is not installed on the development machine. Every one is queued
under "Slice 010" in `issues/hitl-queue.md`, and the single most uncertain item is flagged there:
whether rewriting the item's state chunk is enough to make REAPER re-read an image file it has
already failed to load once. If it is not, the fix is a different nudge, not a different design.

Two modules were added and one was extracted:

- `core.recovery` — pure. `plan(stored)` answers `NONE`, `CHORD` or `DAMAGED` for one item's stored
  voicing, and `summary(tally)` is the text the sweep reports. Specced.
- `adapter.diagram` — the render-and-attach step, lifted out of the entry script so that Apply, the
  silent repair and the sweep are the same code in the same order.
- `preflight.sweepRefusal` — the installation checks the editor makes, without the selection ones.
