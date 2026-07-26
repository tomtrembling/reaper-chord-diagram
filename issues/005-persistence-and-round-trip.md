# 005 — Persistence and round-trip editing

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Store the voicing as structured data on the item, and read it back, so that a chord can be edited
rather than only recreated. This is what makes the item data the source of truth and the image a
derivative, as described under *Anchoring and attachment* in the parent PRD.

Running the action on an item that already carries a chord loads that voicing rather than starting
blank. Because editing a voicing produces a new hashed filename, an edit never overwrites a file
REAPER may still be displaying from cache.

All item writes are wrapped in a single undo block, so a chord behaves like any other REAPER edit.

## Acceptance criteria

- [ ] The voicing is stored as structured data on the item alongside the image reference
- [ ] Running the action on an item that already has a chord loads its voicing as the starting point
- [ ] Changing only the name updates the title and the item name without altering the shape
- [ ] Every write is wrapped in a single undo block, and Ctrl+Z restores the item's previous state
- [ ] Editing a voicing writes a new image file rather than overwriting the previous one
- [ ] The displayed diagram updates to the edited voicing, with no stale image shown
- [ ] Copying an item carries its voicing data to the copy
- [ ] Specs: stored data round-trips back to an identical voicing
- [ ] Specs: chunk transformation replaces the image on an item that already carries a chord,
      leaving unrelated chunk content untouched

## Blocked by

- Blocked by `issues/003-typed-chord-to-diagram.md`

## User stories addressed

- User story 20
- User story 22
- User story 23
- User story 24
- User story 28
- User story 31
