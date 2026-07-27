# HITL queue — deferred human checks

Everything in this file needs a human: the developer's eyes, or the tester's Windows machine.
The agent workflow **never blocks** on these. Each AFK slice appends what it could not verify
itself, and the whole queue is worked through in one pass at the end.

Format: one section per slice, each item a checkbox with enough context to act on without
re-reading the slice.

## How to run this pass

1. `make verify` on the dev machine, then `make index` and push, so the tester's ReaPack
   synchronise pulls the build every item below refers to.
2. Work down the queue in order. Anything that fails becomes a new issue file rather than a
   patch-in-place, so the failure is recorded.

---

<!-- Slices append below. -->

## Slice 003 — typed chord to a real rendered diagram

The action is `Chord Diagram/chord_diagram.lua` (the old `chord_diagram_spike.lua` is still in the
repository as the reference implementation). It needs `src/` alongside it once installed — see the
packaging note at the end.

### Must be captured from REAPER — a spec depends on it

- [ ] **Capture two real item state chunks and replace the reconstructed fixtures.**
      `spec/fixtures/item_chunks.lua` is written from the documented format, not captured from
      REAPER, because REAPER is not installed on the dev machine. The PRD requires real chunks for
      exactly this module, since a bad chunk write corrupts a user's item.
      To capture: select an empty item and run a one-line ReaScript —
      `local ok, c = reaper.GetItemStateChunk(reaper.GetSelectedMediaItem(0,0), "", false)
      reaper.ShowConsoleMsg(c)` — then paste the result over `M.EMPTY_ITEM`. Repeat on an item that
      already carries a chord diagram for `M.ITEM_WITH_CHORD`, and on an audio item for
      `M.AUDIO_ITEM`. Re-run `make test`; any failure is a real defect in `src/core/chunk.lua`,
      not in the test.
      The `M.ITEM_WITH_CHORD` capture now answers a second question as well: how REAPER serialises
      the item's extended state (`P_EXT:chorddiagram`, where the voicing lives) into the chunk. That
      form is deliberately absent from the fixture rather than guessed at — see the banner at the
      top of the file. Once captured, the encoded voicing should be visible somewhere in it.

### Confirm on Windows

- [ ] **A typed chord produces a correct diagram.** Empty item selected, run the action, enter
      `x32010` and the name `C`. Expect: muted low E as a cross above the nut, dots at frets 3, 2
      and 1 on the A, D and B strings, open rings above the nut on the G and high E.
- [ ] **The chord name is centred as a title.** `JS_LICE_DrawText` is given the full width of the
      canvas as its box; whether LICE centres text inside that box or left-aligns it was never
      checked in slice 002. If the title sits hard against the left edge, that is a real bug and
      needs either a LICE text-alignment flag or manual centring.
- [ ] **The chord name is findable in the Media Item Manager** (View > Media Item Manager). The
      name is written into the item's NOTES block, because an empty item has no take to hold a
      name and the notes block has to be non-empty anyway for `IMGRESOURCEFLAGS` to take effect.
      If the Item Manager does not surface it, the fallback to investigate is
      `reaper.GetSetMediaItemInfo_String(item, "P_NOTES", ...)` or a name column that reads takes
      only — in which case raise a new issue.
- [ ] **The relative image path still resolves.** Slice 003 changed the path stored in
      `RESOURCEFN` from the platform separator the spike used to a forward slash, so a project made
      on Windows opens on macOS. Confirm the diagram still appears on Windows.
- [ ] **Identical chords share one file.** Apply the same chord and name to two empty items;
      `chord-diagrams/` should contain exactly one PNG and both items should show it.
- [ ] **Invalid input changes nothing.** Enter `x3201z`; expect a message naming the bad character
      and an item left exactly as it was.
- [ ] **Ctrl+Z reverts the chord** in one step, like any other REAPER edit.
- [x] ~~**Judgement call: high-position chords are unlabelled until slice 004.**~~ **Closed by slice
      004** — the marker now renders, so there is no gap to confirm. Enter `x79987` and the diagram
      says `7fr`; the check for that lives under slice 004 below.

### Packaging — for the orchestrator, not the tester

- [ ] **Decide how `src/` reaches the installed script.** The plugin is no longer one file. The
      entry script puts both `<script dir>/src` and `<script dir>/../src` on `package.path`, so
      either layout works: ReaPack can install the modules beside the script, or one directory up.
      Nothing was changed in `index.xml` and `make index` was not run.

## Slice 005 — persistence and round-trip editing

The voicing is stored on the item as one encoded token:

```
v1;s=6;f=-1,3,2,0,1,0;g=0,0,0,0,0,0;b=;p=;n=Cadd9
```

One token, no whitespace and no quotes, everything else percent-escaped, versioned with `v1`.

**The storage mechanism changed after slice 005 was first written, and this section was rewritten
to match.** Slice 005 put that token on a bespoke `CHORDDIAGRAM` line inside the item state chunk,
and flagged as a blocking risk the question of whether REAPER keeps a chunk line it does not
recognise across a project save. It almost certainly does not — REAPER reserialises an item chunk
from its own model, and a line it has no field for has nowhere to live. Rather than send you to
test a gamble, the token now goes into REAPER's documented per-item extended state,
`GetSetMediaItemInfo_String(item, "P_EXT:chorddiagram", …)`, which is saved with the project by
design. This is also what the PRD asked for under *Anchoring and attachment*. The encoded string is
byte-for-byte identical, so nothing below is about the format. **There is no longer a
`CHORDDIAGRAM` line to look for in the `.RPP`; do not go hunting for one.**

### Confirm on Windows

- [ ] **A chord survives save, close and reopen.** Apply a chord, save the project, close it,
      reopen it, and run the action on that item again. The chord and the name must come back
      pre-filled in the dialog. This is the cheap replacement for slice 005's blocking risk: it
      confirms extended state persists, which is the one assumption the storage change rests on.
      If it fails, that is a real defect — raise a new issue rather than patching in place.

- [ ] **Reopening an item pre-fills its chord.** Apply `x32010` named `C`, run the action again on
      the same item, and expect both fields already filled in rather than blank.
- [ ] **Editing writes a new image and the item shows it.** With the above item, change the chord to
      `x32013` and apply. `chord-diagrams/` should now hold two PNGs, and the item must show the new
      diagram immediately — no stale picture. This is the caching behaviour the hashed filename
      exists to sidestep, so it is the interesting one.
- [ ] **Renaming changes only the title.** Reopen the same item, leave the chord alone, change the
      name to `C major`. The shape must be identical and only the title different.
- [ ] **Copying an item carries the chord.** Copy an item with a chord and paste it elsewhere, then
      run the action on the copy: it must pre-fill with the same voicing. This is what proves the
      data is not keyed to item identity. It matters more since the storage change: the chunk line
      was self-evidently copied with the chunk, whereas that REAPER duplicates a `P_EXT:` value
      along with the item could not be confirmed from documentation on the dev machine, so it is
      checked here rather than assumed. If the copy comes up blank, the fallback is to read the
      voicing off the source item and write it to the copy explicitly — raise it as an issue.
- [ ] **Ctrl+Z reverts an edit in one step**, restoring both the previous image and the previous
      stored voicing. Two REAPER writes now happen inside the undo block — the state chunk, then
      the extended state — so this also confirms they collapse into a single undo point rather than
      needing two presses.
- [ ] **A name with a comma still round-trips.** Name a chord `C, second inversion` and reopen it.
      The dialog is comma-separated, so this exercises `dialog.prompt`'s rejoin as well as the
      storage escaping.

### Judgement call to confirm

- [x] ~~**A base-fret override survives a text edit.**~~ **Settled by slice 004.** The override is
      now carried across a text edit only while it can still frame the chord — every fretted note
      inside its five-fret window — and dropped when it cannot. Nothing to test by hand; it is
      covered by specs. See the slice 004 commit for the reasoning.

## Slice 004 — fret framing and high-position voicings

Version 0.8.0. Everything here is about what the diagram looks like, so it needs eyes rather than
a spec.

### Confirm on Windows

- [ ] **A high-position chord is labelled with the fret it starts at.** Enter `x79987` named `Bm`.
      Expect no heavy nut line, a `7fr` marker in the empty space to the LEFT of the grid level
      with the first fret cell, and dots in cells 1, 3, 3, 2, 1 across the A, D, G, B and high E.
- [ ] **A chord typed in the separated form draws correctly.** Enter `10-12-12-11-10-10` named
      `D`. Expect a `10fr` marker and a barre-shaped block of dots. Reopen the item: the field must
      come back as `10-12-12-11-10-10`, not `101212111010`.
- [ ] **The marker is legible and does not collide with the grid.** This is the one piece of
      geometry slice 002 never tuned by eye — the gutter left of the grid was empty until now. Look
      at a two-digit marker in particular (`12-14-14-13-12-12`), which is the widest text that has
      to fit. If it is clipped, cramped, or hard against the left edge of the image, that is a real
      defect: the marker's size is `POSITION_HEIGHT` in `src/core/layout.lua`.
- [ ] **The marker sits where the title does horizontally — or does not.** Its text box is given
      `align = "centre"`, and the LICE backend does not act on that field; whether LICE centres
      text in the box it is given is the same open question as the slice 003 title item above.
      Answer both at once: if the title is left-aligned in its box, the marker will be hard against
      the left edge of the canvas.
- [ ] **The dialog still fits with the longer chord label.** The label is now
      `Chord (e.g. x32010 or 10-12-12-11-10-10)`. If the native dialog truncates it or grows
      absurdly wide, shorten the label — this dialog is replaced by the ImGui window in slice 006
      anyway, so do not spend long on it.

### Judgement calls to confirm

- [ ] **A comma-separated chord cannot be typed into this dialog.** The parser accepts
      `10,12,12,11,10,10`, but `dialog.prompt` splits REAPER's reply on commas and rejoins the
      surplus into the LAST field, so the chord arrives as `10` and the name as the rest. The label
      steers people to hyphens. Confirm that is enough for now; it fixes itself in slice 006 when
      the ImGui window gives each field its own box.
- [ ] **A high chord with an open string keeps the window rather than the nut.** Enter
      `x-0-9-9-7-x`. The shape reaches the ninth fret, so the nut cannot be shown without putting
      the dots off the diagram: it frames from the seventh and still draws an open ring above the A
      string. That is how songbooks notate it, but it is a judgement call — confirm it reads
      correctly rather than looking like a mistake.

## Slice 006 — the ImGui window with a clickable grid

Version 0.9.0. **The native input dialog is gone.** Running the action now opens a window with a
fretboard grid; there is no text field and no name field until slice 007, so several slice 003, 004
and 005 checks above can no longer be performed as written — see *Checks above that this slice
invalidates* at the end of this section before working the queue.

This is the first slice whose main deliverable cannot be executed at all on the development
machine. Nothing below has been run; `make verify` only parses it.

### The one that decides whether anything else can be checked

- [ ] **THE WINDOW OPENS.** If it does not, this is the first thing to look at, because the binding
      is a guess made from documentation rather than from a running REAPER.

      ReaImGui changed how a script reaches it at version 0.9. `src/adapter/imgui.lua` tries the
      current documented way first —

      ```lua
      package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
      local ImGui = require 'imgui' '0.9'
      ```

      — detected by whether `ImGui_GetBuiltinPath` exists, since that function arrived with the
      shim in 0.9. If it does not exist, the module falls back to the pre-0.9 style of calling
      `reaper.ImGui_*` directly, building the same table by hand and calling the constant getters
      (`reaper.ImGui_Key_Escape()`) that the newer API exposes as plain values. Everything else in
      the project talks to that one table and cannot tell which style won.

      **Telling the two failures apart from the symptom:**

      | What you see | What it means |
      | --- | --- |
      | "This action needs ReaImGui" | ReaImGui is not installed at all. Install it via ReaPack. |
      | "ReaImGui cannot provide API version 0.9" | The install predates 0.9 *and* the fallback was not taken — report the ReaImGui version. |
      | "This version of ReaImGui does not provide *name*" | The fallback was taken and that install is too old for that call. Report the name and the version. |
      | "ReaImGui's shim could not be loaded" | `imgui.lua` is missing from `Scripts/ReaTeam Extensions/API/`. Reinstall ReaImGui through ReaPack. |
      | Nothing happens, no message, no window | The binding resolved but a call inside the frame failed. Open the ReaScript console (Actions > Show console output) and paste whatever is there into the issue. |

      The version asked for is `0.9`, not the newest, deliberately: the shim exists so a script can
      name an older API and still run on newer installs. `M.API_VERSION` in
      `src/adapter/imgui.lua` is the one place to change it.

      **Please record the ReaImGui version installed on the test machine either way**, pass or
      fail. It is the fact that would have made this a decision rather than a guess.

### Confirm on Windows

- [ ] **The grid looks like the exported PNG.** Both are drawn from the same primitive list, so
      any difference in *geometry* is a real bug. Two differences are expected and are not bugs:
      the on-screen title and fret marker use the ImGui window font at its own size rather than
      the size the layout asks for, so they read smaller than in the image; and the on-screen
      ring above an open string is a stroked circle where the PNG punches a white disc out of a
      black one. Anything else that differs — spacing, dot positions, which fret a dot is in — is
      the drift this architecture exists to prevent, so raise it as an issue.
- [ ] **A click lands on the cell it appears to land on.** Click the third fret of the A string;
      the dot must appear under the pointer, not one cell out. Check the top and bottom cells and
      both outer strings especially, since an off-by-one in the hit test shows up at the edges
      first. The round trip is specced (`spec/core/layout_spec.lua`), but only the specs' idea of
      where the mouse is — this confirms ImGui's idea agrees.
- [ ] **Clicking a cell places a dot and clicking it again removes it**, leaving that string
      MUTED (a cross above the nut), not open. That is a deliberate choice — see the judgement
      call below.
- [ ] **Clicking above the nut toggles a string between open and muted**, and clicking above the
      nut on a string that has a dot lifts the dot and rings the string open.
- [ ] **Apply writes the chord and closes the window** in one press.
- [ ] **Cancel closes the window and the item is untouched** — no new PNG in `chord-diagrams/`, no
      change to the item, and nothing on the undo stack to press Ctrl+Z through.
- [ ] **Escape closes the window**, same as Cancel. The window must have focus for ImGui to see
      the key; if Escape only works when the window is focused that is correct behaviour, not a
      bug.
- [ ] **The window can be resized and the grid follows.** The grid is recomputed from the window's
      available space every frame, so it should stay square and stay clickable at any size. Drag
      it small: below a floor the grid stops shrinking and the buttons scroll, which is intended.
- [ ] **Running the action on an item that already carries a chord opens the grid already filled
      in**, and the title of the window's diagram is the name that chord already had.
- [ ] **Two runs in a row do not leave a window behind.** The lifecycle is one-shot: the loop stops
      deferring after Apply, Cancel or Escape, and ReaImGui destroys a context that stops being
      used. If a ghost window survives, say so — the pre-0.9 fallback path had an explicit
      `DestroyContext` that the current API removed, and this code deliberately calls neither.

### Judgement calls to confirm

- [ ] **Clearing a dot returns the string to MUTED rather than OPEN.** Clicking a dot off is a
      deletion, and muted is the state that claims nothing: a string is not sounded until the user
      says so above the nut. The alternative — clearing to open — would silently add a ringing
      string to the diagram every time a finger is removed. Confirm this reads correctly to a
      guitarist; if clearing to open feels more natural in practice, that is a one-line change in
      `core.voicing.toggleFret` and a spec.
- [ ] **A NEW CHORD IS NAMED WITH ITS OWN CHORD STRING UNTIL SLICE 007.** The name came from the
      native input dialog, which this slice removes, and the name field is slice 007. Rather than
      keep a dialog in front of the window for one field, a chord created in this version falls
      back to the rule that was already there for an unnamed chord: the title is its chord string,
      so `x32010` is titled "x32010". Reopening a chord that already has a name keeps that name, so
      nothing already applied loses its title. **This is a known one-slice gap, not a defect** —
      please do not raise it as a bug, but do say if titling by chord string is actually preferable
      to a free-text default.

### Checks above that this slice invalidates

Work these with the new UI in mind rather than skipping them:

- Anything that says "type `x32010`" is now "click the shape in". The expected diagram is
  unchanged, so the check still means something.
- **Slice 004's "the dialog still fits with the longer chord label"** — dead. There is no dialog.
- **Slice 004's "a comma-separated chord cannot be typed into this dialog"** — dead for the same
  reason; the text field in slice 007 will have its own box and no comma problem.
- **Slice 005's "a name with a comma still round-trips"** — cannot be performed until slice 007
  gives the name a field. The storage escaping it was testing is specced, so it is a deferral
  rather than a loss.
- Every slice 004 check that needs a high-position chord (`x79987`, `10-12-12-11-10-10`,
  `12-14-14-13-12-12`) can still be entered by clicking, but the grid only shows five frets at a
  time and the framing follows the shape, so build the shape from its lowest fretted note upward.
  If that turns out to be unreasonably fiddly by hand, do those checks after slice 007 instead.
