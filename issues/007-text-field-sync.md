# 007 — Text field synced with the grid

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Bring the chord-string fast path into the UI, synced bidirectionally with the grid: typing redraws
the grid, clicking the grid rewrites the text. This is what makes a common voicing a couple of
seconds of typing rather than six mouse clicks.

Also adds the remaining controls: the name field, and the manual base-fret override alongside the
auto-derived value from slice 004.

**The important part is the merge semantics.** Re-parsing the text field must merge into the
existing voicing rather than replace it wholesale. Barres arrive in the next slice and cannot be
expressed in text at all, so a replace-on-parse implementation would silently discard them the
moment a user nudges one string. Build the merge behaviour now, while it is cheap, and spec it —
see *Interaction model* in the parent PRD.

## Acceptance criteria

- [ ] A text field shows the chord string for the current voicing
- [ ] Typing a valid chord string redraws the grid immediately
- [ ] Clicking the grid rewrites the text field to match
- [ ] Invalid or partial text does not corrupt the current voicing or throw
- [ ] A name field is present and its value is used for the title and item name
- [ ] The base fret shows its auto-derived value and can be overridden with a control
- [ ] Overriding the base fret reframes the diagram without altering the voicing itself
- [ ] Re-parsing text merges into the existing voicing rather than replacing it
- [ ] Specs: merge semantics preserve voicing attributes that the text form cannot express

## Blocked by

- Blocked by `issues/004-fret-framing.md`
- Blocked by `issues/006-imgui-grid-window.md`

## User stories addressed

- User story 5
- User story 6
- User story 11
