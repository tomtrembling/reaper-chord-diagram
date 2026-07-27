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

- [x] Dragging across strings at a fret creates a barre spanning those strings
- [x] The barre renders in both the on-screen grid and the exported image
- [x] A barre can be removed
- [x] Partial barres spanning only some strings are supported
- [x] No barre is ever created without an explicit user gesture
- [x] Editing the text field on a chord that has a barre preserves that barre
- [x] A barre survives the full round-trip: apply, reopen the item, and it is still there
- [x] Specs: barre geometry spans the correct strings at the correct fret
- [x] Specs: text edits on a barred voicing preserve the barre

## What was built

`voicing.setBarre(v, fret, from, to)` sits beside `setFret`, `setName` and `setBaseFret` with the
same contract: it returns a new voicing and never mutates. **It moves no finger.** An F is barred at
the first fret with three fingers above the bar, so a gesture that also fretted the strings it
covers would flatten the chord the moment the bar was drawn in. One bar per fret, replaced by a
second drag across the same fret; ends stored low string first, so the direction of the drag does
not matter; `from`/`to` nil removes.

`layout.compute` emits a new `barre` role as three primitives — a rectangle from the first string
covered to the last, plus a round cap at each end — rather than one thick line, because a line's end
caps are the backend's business and LICE and ImGui disagree about them. A rect and a filled circle
are drawn identically by both, so the bar in the PNG is the bar on screen. **No backend changed**:
both already painted those two kinds. The bar is emitted before the dots, and the dots of the
strings it covers are still drawn, on top of it.

The gesture, in `grid()` in `src/adapter/imgui.lua`: a press that ends on the string it started on
is a click, and one that ends on a different string of the same fret row is a barre. Removal is a
click on a cell the bar covers, which routes through `voicing.toggleFret` — a click cannot be
mistaken for a drag, because creating a barre requires the pointer to travel.

Nothing infers a barre, and a spec asserts it: four textbook barre shapes are pushed through
`parse`, `setFret`, `toggleFret`, `setName` and a storage round trip, and none comes back carrying a
bar. The storage format needed no change — it has carried barres since slice 005.

The gesture cannot be executed on the development machine. `issues/hitl-queue.md` under *Slice 008*
leads with how to tell a click apart from a drag, and carries four judgement calls and two items for
the slice 011 style pass.

## Blocked by

- Blocked by `issues/007-text-field-sync.md`

## User stories addressed

- User story 8
- User story 9
- User story 21
