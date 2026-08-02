# 011 — Visual style pass

## Type

HITL — requires design review, and confirmation on Windows.

## Parent PRD

`issues/prd.md`

## What to build

Settle the diagram's appearance now that every element that can appear on one exists: dots, open and
muted markers, barres, the position marker, and the title.

One opinionated default, close enough to established chord-chart conventions that a guitarist reads
it instantly. No settings UI — see *Out of Scope* in the parent PRD.

The legibility target is set by how the diagram is actually used: it must read at the item sizes
people really use, not only when blown up.

## Acceptance criteria

- [ ] Dot size, spacing, stroke weights and colours reviewed and settled
- [ ] Title placement and size settled
- [ ] Position marker placement and size settled
- [ ] The diagram is legible at a typical item height and remains sharp when dragged tall
- [ ] The style reads correctly against both light and dark REAPER themes, or a deliberate choice is
      recorded
- [ ] Fonts used exist on both macOS and Windows
- [ ] Appearance confirmed on Windows by the tester
- [ ] No user-facing style settings are introduced
- [ ] **Diagrams already written to disk pick up the new style.** An image's filename hashes the
      VOICING, not the drawing, so restyling changes no filename: `adapter.diagram.attach` finds the
      old file present and skips the render, and the regenerate action only rebuilds what is
      missing. A style pass that leaves a project full of old-style diagrams has not landed. The two
      routes — a style version in the hash, or a "rebuild everything" mode on the regenerate action —
      are set out under *For the slice 011 style pass* in `issues/hitl-queue.md`.

## Blocked by

- Blocked by `issues/008-barre-drag.md`

## User stories addressed

- User story 18
- User story 19

## Notes

- Slice 012 moved the title's and the position marker's boxes so that the LICE backend's
  left-aligned text lands over the grid and inside the gutter rather than against the edge of the
  image (D22). That settles PLACEMENT for the export; SIZE is still open and is this pass's — the
  box is the clip rectangle and nothing can measure a string to shrink it, so a long name still runs
  out of room. `12fr` in the gutter is the tightest case.
