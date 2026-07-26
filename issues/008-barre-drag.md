# 008 — Barre entry by dragging

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Barres, entered by dragging across the strings to be barred. Nothing is ever inferred — the plugin
must never draw a barre the user did not ask for, so that a diagram never claims a fingering they
didn't choose. See *Interaction model* in the parent PRD.

The barre is rendered from the shared layout primitives, so it appears identically in the grid and
in the exported image.

This slice is where the merge semantics built in slice 007 are proven: a barre chord whose text is
edited afterwards must keep its barre.

## Acceptance criteria

- [ ] Dragging across strings at a fret creates a barre spanning those strings
- [ ] The barre renders in both the on-screen grid and the exported image
- [ ] A barre can be removed
- [ ] Partial barres spanning only some strings are supported
- [ ] No barre is ever created without an explicit user gesture
- [ ] Editing the text field on a chord that has a barre preserves that barre
- [ ] A barre survives the full round-trip: apply, reopen the item, and it is still there
- [ ] Specs: barre geometry spans the correct strings at the correct fret
- [ ] Specs: text edits on a barred voicing preserve the barre

## Blocked by

- Blocked by `issues/007-text-field-sync.md`

## User stories addressed

- User story 8
- User story 9
- User story 21
