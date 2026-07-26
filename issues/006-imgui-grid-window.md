# 006 — ImGui window with an interactive grid

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Replace the native input dialog with the real UI: a window containing a fretboard grid that the
user clicks to build a shape.

The grid is drawn by the ImGui backend from the **same layout primitives** the image renderer uses,
so what the user sees matches what gets exported. Hit-testing reuses those same coordinates, which
is what guarantees a click lands on the cell it appears to land on.

Window lifecycle is one-shot, per *Interaction model* in the parent PRD: select item, hotkey, edit,
Apply, closed. No selection watching and no background state.

## Acceptance criteria

- [ ] The window opens with a grid drawn from the shared layout primitives
- [ ] Clicking a cell places a dot; clicking it again clears it
- [ ] Strings can be toggled between open and muted above the nut
- [ ] The on-screen grid visibly matches the diagram that gets exported
- [ ] Apply writes the chord to the item and closes the window
- [ ] Cancel, and the Escape key, close the window leaving the item unchanged
- [ ] The window becomes the primary entry path, replacing the native dialog
- [ ] Specs: hit-testing round-trips — a coordinate generated for a given string and fret maps back
      to that same string and fret

## Blocked by

- Blocked by `issues/003-typed-chord-to-diagram.md`
- Blocked by `issues/005-persistence-and-round-trip.md`

## User stories addressed

- User story 4
- User story 13
- User story 14
- User story 15
