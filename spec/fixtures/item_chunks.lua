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
--- ## Replacing them with genuine captures is an open item in                ##
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

--- An empty item that already carries a chord diagram: a notes block holding
--- the chord name, plus the two image fields.
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
RESOURCEFN "chord-diagrams/8fbb1c2d9a4e7051.png"
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
