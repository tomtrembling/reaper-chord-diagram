--- Item state chunks used as inputs to the Chunk specs.
---
--- ############################################################################
--- ## THESE CHUNKS ARE RECONSTRUCTED, NOT CAPTURED.                          ##
--- ##                                                                        ##
--- ## The PRD asks for real item state chunks captured from REAPER, because  ##
--- ## chunk corruption is the project's highest-consequence failure. REAPER  ##
--- ## is not installed on the development machine and no captured chunk      ##
--- ## exists anywhere in this repository's history, so these were written    ##
--- ## from the documented format (ReaTeam's State Chunk Definitions) and the ##
--- ## field order the spike's `withImage` was built against.                 ##
--- ##                                                                        ##
--- ## ONE THING IS DELIBERATELY ABSENT rather than reconstructed: how REAPER ##
--- ## serialises an item's extended state — the `P_EXT:chorddiagram` value   ##
--- ## the voicing is stored under — into the chunk. That form is not known   ##
--- ## here, and writing a plausible-looking guess would be worse than an     ##
--- ## omission, because the specs would then depend on a fiction. `core`     ##
--- ## .chunk never reads or writes it; what protects it is the spec saying   ##
--- ## an unrecognised line is carried through, which holds whatever the real ##
--- ## serialisation looks like.                                              ##
--- ##                                                                        ##
--- ## Replacing all of this with genuine captures is an open item in         ##
--- ## issues/hitl-queue.md under slice 003. Until that is done, a passing    ##
--- ## Chunk spec proves the transformation is correct against the format as  ##
--- ## documented — not against the format REAPER actually emits.             ##
--- ############################################################################
local M = {}

--- An empty item as REAPER writes it before the plugin has ever touched it:
--- no take, no notes, no image.
M.EMPTY_ITEM = [[
<ITEM
POSITION 8.5
SNAPOFFS 0
LENGTH 4
LOOP 1
ALLTAKES 0
FADEIN 1 0.01 0 1 0 0 0
FADEOUT 1 0.01 0 1 0 0 0
MUTE 0 0
SEL 1
IGUID {8D3C1A20-4E7B-4C3F-9A21-5B6E0F7D2C84}
IID 7
NAME ""
VOLPAN 1 0 1 -1
SOFFS 0
PLAYRATE 1 1 0 -1 0 0.0025
CHANMODE 0
GUID {2F9A6B14-7C05-48D3-B1E6-3A8C4D9E0F52}
>
]]

--- An empty item that already carries a chord diagram: a notes block holding the
--- chord name, and the two image fields. That is the whole of what this plugin
--- puts in a chunk.
---
--- The chord is `x32010` named `Cadd9`, and the image filename is that voicing's
--- real fingerprint, so the fixture is internally consistent — a reader can
--- check the hash rather than take it on trust.
---
--- The voicing itself is NOT here. Slice 005 wrote it onto a `CHORDDIAGRAM` line
--- in this chunk; that was reversed, because REAPER rebuilds an item chunk from
--- its own model and promises nothing about a line it does not recognise. It now
--- lives in the item's extended state under `P_EXT:chorddiagram`, written
--- through `adapter.item`, so a real capture of this item would carry it in
--- whatever form REAPER uses for that — see the banner above.
M.ITEM_WITH_CHORD = [[
<ITEM
POSITION 8.5
SNAPOFFS 0
LENGTH 4
LOOP 1
ALLTAKES 0
FADEIN 1 0.01 0 1 0 0 0
FADEOUT 1 0.01 0 1 0 0 0
MUTE 0 0
SEL 1
IGUID {8D3C1A20-4E7B-4C3F-9A21-5B6E0F7D2C84}
IID 7
NAME ""
VOLPAN 1 0 1 -1
SOFFS 0
PLAYRATE 1 1 0 -1 0 0.0025
CHANMODE 0
GUID {2F9A6B14-7C05-48D3-B1E6-3A8C4D9E0F52}
<NOTES
|Cadd9
>
RESOURCEFN "chord-diagrams/3a8f57a773ffd3a0.png"
IMGRESOURCEFLAGS 3
>
]]

--- An audio item, carrying a nested sub-chunk. Nothing in this file should ever
--- be reordered or lost by a transformation that only means to touch the image
--- fields.
M.AUDIO_ITEM = [[
<ITEM
POSITION 0
SNAPOFFS 0
LENGTH 12.25
LOOP 1
ALLTAKES 0
FADEIN 1 0.01 0 1 0 0 0
FADEOUT 1 0.01 0 1 0 0 0
MUTE 0 0
SEL 0
IGUID {1B7E4C09-3D62-4F18-A5C7-9E0B2D4A6F31}
IID 2
NAME guitar-di-01.wav
VOLPAN 1 0 1 -1
SOFFS 0
PLAYRATE 1 1 0 -1 0 0.0025
CHANMODE 0
GUID {6C0F3A85-2E49-4B7D-8130-5A9E7C1B4D26}
<SOURCE WAVE
FILE "audio/guitar-di-01.wav"
>
>
]]

return M
