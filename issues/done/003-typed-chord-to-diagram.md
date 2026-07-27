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

## Settled rendering configuration — carry this forward

Slice 002 established the following over four runs on the tester's machine. **These are settled; do
not re-derive them.** The working reference implementation is
`Chord Diagram/chord_diagram_spike.lua`, which this slice refactors into the proper modules.

| Setting | Value | Why |
|---|---|---|
| `IMGRESOURCEFLAGS` | **3** | The only value that never repeats the image. 1 and 5 keep proportions but tile on wide items. |
| Canvas | **1024 × 1024**, square, power of two | Confirmed good at all usable item sizes; the square shape keeps flag 3's stretching mild. |
| Stroke weight | **proportional to canvas size** (`SIZE/64`) | A fixed pixel width vanishes when REAPER scales the image down to item height. Never use a fixed stroke. |
| Image path | relative, under `<project>/chord-diagrams/` | REAPER resolves it against the project, keeping projects portable between machines. |
| Chunk write | `RESOURCEFN` + `IMGRESOURCEFLAGS`, inserted before the chunk's closing `>`, with a non-empty `<NOTES>` block | The flags line is ignored when notes are empty. |
| Title clearance | title band ends at 0.17 of canvas height, marker row at 0.245 | Anything tighter and the chord name crosses into the diagram. |

The spike's `LAYOUT` table holds the vertical proportions that were tuned visually — reuse those
numbers in the layout module rather than inventing new ones.

Two API notes that cost time to establish: `JS_LICE_WritePNG` takes `(path, bitmap, wantAlpha)`, and
text needs `JS_GDI_CreateFont` → `JS_LICE_CreateFont` → `JS_LICE_SetFontFromGDI` → `JS_LICE_DrawText`
with Arial, which exists on both platforms.

## Acceptance criteria

- [x] The action prompts for a chord string and a name using REAPER's native input dialog
- [x] Strings in the `x32010` form parse into a voicing, with open and muted strings distinguished
- [x] Open and muted strings render above the nut
- [x] The diagram is drawn from the shared layout definition, not from bespoke drawing code
- [x] The chord name renders as a title on the diagram
- [x] The chord name is also written to the item's name field and is visible in the Item Manager
      — written to the item's NOTES block, which is the only name an empty item has. Visibility in
      the Item Manager is a HITL check.
- [x] Image filenames derive from a hash of the voicing
- [x] Two items given the same voicing reference the same image file
- [x] Invalid input is rejected with a clear message and the item is left untouched
- [x] Specs: chord string parses to the expected voicing, and formatting round-trips back
- [x] Specs: layout produces expected geometry for known voicings
- [ ] Specs: chunk transformation against real captured item chunks — attaching to an item with no
      notes, and leaving unrelated chunk content untouched
      — **the transformation is specified and green, but against RECONSTRUCTED chunks.** REAPER is
      not installed on the dev machine and no captured chunk exists in this repository's history.
      `spec/fixtures/item_chunks.lua` says so at the top of the file, and replacing the fixtures
      with real captures is the first item under slice 003 in `issues/hitl-queue.md`.

## Blocked by

- Blocked by `issues/002-tracer-bullet-chord-on-item.md`

## Outcome — interfaces settled here, which slices 004-010 inherit

**Voicing** (`src/core/voicing.lua`). A voicing is a plain table:
`{ strings, frets, fingers, barres, baseFret, name }`. `frets` holds one absolute fret per string,
low E first, with `-1` muted and `0` open. `barres` and `fingers` exist and are carried through the
fingerprint, but nothing writes or draws them yet. `baseFret` is nil when derived and set only by a
manual override. Interface: `parse(text, name) -> voicing | nil, err`, `toText`, `baseFret`,
`fingerprint`, `new(opts)`. `setFret` and `setBarre` are deliberately absent — there is nothing to
call them until the grid exists in 006 and 008.

**The fingerprint includes the name**, because the name is drawn on the diagram. Two items sharing
a shape but not a name must not share an image file, or a rename would leave the wrong title on
screen. It is FNV-1a rendered as 16 lowercase hex digits: no case, no separators.

**Layout** (`src/core/layout.lua`). `compute(voicing, width, height)` returns
`{ width, height, voicing, primitives }`. Primitives are `line`, `rect`, `circle` and `text` with a
semantic `colour` ("ink"/"paper") and a `role` naming the part they play ("nut", "fret", "string",
"dot", "open", "muted", "title"). Coordinates are a unit square: x and y run 0..1, and scalar sizes
are fractions of the side. A backend multiplies x by width, y by height and scalars by the smaller.
`cellAt(computed, x, y)` takes coordinates in the surface's own units and returns string index and
absolute fret, with 0 meaning the row above the nut. It re-derives its geometry from the same
private `grid` the primitives came from, so a click lands on exactly what was drawn.

**Chunk** (`src/core/chunk.lua`). `setImage(chunkText, { filename, flags, notes })`
`-> chunkText | nil, err`. Refuses empty notes, because REAPER ignores `IMGRESOURCEFLAGS` without
them. Replacement is done through a function so a `%` in a chord name is taken literally — the
spike's string replacement would have corrupted the chunk on any name containing one. `readVoicing`
and its writer belong to slice 005 and are not here.

**The relative path in `RESOURCEFN` uses forward slashes**, not the platform separator the spike
used, so a project written on Windows resolves on macOS. Only the absolute filesystem path handed
to `JS_LICE_WritePNG` uses the platform separator. Unconfirmed on Windows; in the HITL queue.

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
