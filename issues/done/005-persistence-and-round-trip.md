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

- [x] The voicing is stored as structured data on the item alongside the image reference
- [x] Running the action on an item that already has a chord loads its voicing as the starting point
- [x] Changing only the name updates the title and the item name without altering the shape
- [x] Every write is wrapped in a single undo block, and Ctrl+Z restores the item's previous state
- [x] Editing a voicing writes a new image file rather than overwriting the previous one
- [x] The displayed diagram updates to the edited voicing, with no stale image shown
- [x] Copying an item carries its voicing data to the copy
- [x] Specs: stored data round-trips back to an identical voicing
- [x] Specs: chunk transformation replaces the image on an item that already carries a chord,
      leaving unrelated chunk content untouched

## Blocked by

- Blocked by `issues/003-typed-chord-to-diagram.md`

## What was built

The voicing is stored as one versioned, chunk-safe token on a `CHORDDIAGRAM` line in the item's
state chunk, written in the same chunk write as the image so the picture and the data behind it can
never be one edit apart. `voicing.encode`/`decode` own the format; `chunk.setVoicing`/`readVoicing`
own where it sits in the chunk. `voicing.parse` gained an optional third argument, the voicing being
edited, so re-typing the text merges into the existing chord instead of replacing it — the PRD's
barre-preservation rule.

The criteria that can only be observed inside REAPER — undo, the arrange view refresh, copy/paste —
are implemented and deferred to the HITL queue under *Slice 005*, per the standing brief's HITL
policy. That queue also carries the one genuine risk: whether REAPER preserves an unrecognised item
chunk line across a project save, with a documented fallback if it does not.

## User stories addressed

- User story 20
- User story 22
- User story 23
- User story 24
- User story 28
- User story 31
