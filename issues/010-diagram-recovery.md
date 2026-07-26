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

- [ ] Opening the editor on an item whose image file is missing rebuilds the image
- [ ] The rebuilt image is re-linked to the item and displays without further user action
- [ ] A project-wide action regenerates every missing diagram in the project
- [ ] Deleting the entire image folder and running that action restores all diagrams
- [ ] Items with no stored voicing data are skipped rather than erroring
- [ ] Images that already exist are not needlessly rewritten
- [ ] The action reports how many diagrams it regenerated

## Blocked by

- Blocked by `issues/005-persistence-and-round-trip.md`

## User stories addressed

- User story 29
- User story 30
