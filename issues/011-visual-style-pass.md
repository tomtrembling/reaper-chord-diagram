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

## Blocked by

- Blocked by `issues/008-barre-drag.md`

## User stories addressed

- User story 18
- User story 19
