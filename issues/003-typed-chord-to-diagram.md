# 003 — Typed chord string to a real rendered diagram

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Replace the hardcoded voicing from the tracer bullet with a real one, entered as a chord string.
Use REAPER's native input dialog for entry — the ImGui window comes later, and this slice should
prove the whole logic chain without depending on it.

This is the first slice with real logic, and it stands up all three core modules described under
*Architecture* in the parent PRD: the voicing model (parsing and formatting chord strings), the
layout module (turning a voicing into drawing primitives), and the chunk module (writing the image
reference into the item). The LICE backend is rewired to draw from layout primitives rather than
drawing anything itself, establishing the single shared visual definition that later prevents the
on-screen grid from drifting away from the exported image.

Filenames derive from a hash of the voicing, per *Naming and storage* in the parent PRD.

## Acceptance criteria

- [ ] The action prompts for a chord string and a name using REAPER's native input dialog
- [ ] Strings in the `x32010` form parse into a voicing, with open and muted strings distinguished
- [ ] Open and muted strings render above the nut
- [ ] The diagram is drawn from the shared layout definition, not from bespoke drawing code
- [ ] The chord name renders as a title on the diagram
- [ ] The chord name is also written to the item's name field and is visible in the Item Manager
- [ ] Image filenames derive from a hash of the voicing
- [ ] Two items given the same voicing reference the same image file
- [ ] Invalid input is rejected with a clear message and the item is left untouched
- [ ] Specs: chord string parses to the expected voicing, and formatting round-trips back
- [ ] Specs: layout produces expected geometry for known voicings
- [ ] Specs: chunk transformation against real captured item chunks — attaching to an item with no
      notes, and leaving unrelated chunk content untouched

## Blocked by

- Blocked by `issues/002-tracer-bullet-chord-on-item.md`

## User stories addressed

- User story 1
- User story 2
- User story 7
- User story 12
- User story 18
- User story 25
- User story 32
- User story 42
- User story 43
