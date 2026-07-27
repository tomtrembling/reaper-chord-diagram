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

The action is `Chord Diagram/chord_diagram.lua`. The old spike now lives at
`ref/chord_diagram_spike.lua` and is no longer packaged. Packaging is settled — see the *Packaging
and delivery* section at the end, which must be worked through FIRST, since nothing else in this
queue can be checked until the tester has a working install.

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

- [x] ~~**Decide how `src/` reaches the installed script.**~~ **Settled at 0.14.0** — one package,
      `@provides` retargeting the modules beside the scripts. See *Packaging and delivery* at the
      end of this file for what the tester has to confirm.

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
      Deferred by slice 006, which removed the name field, and **live again from slice 007**, which
      gives it one. It no longer exercises `dialog.prompt`'s rejoin — that is deleted — so it is now
      purely a check on the storage escaping.

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
- [x] ~~**A NEW CHORD IS NAMED WITH ITS OWN CHORD STRING UNTIL SLICE 007.**~~ **Closed by slice
      007** — the name has a field again, so the gap lasted exactly the one slice it was declared
      for. The chord-string title survives as the fallback for a chord nobody names, which is
      checked under slice 007 below.

### Checks above that this slice invalidates

**Mostly reversed by slice 007, which puts the text and name fields back.** Read this list with the
slice 007 section below, which says which of them are live again and how.

- Anything that says "type `x32010`" was "click the shape in" for one slice. **Live again as
  written** — there is a text field.
- **Slice 004's "the dialog still fits with the longer chord label"** — dead, permanently. There is
  no dialog, and the field's label is ImGui's to size.
- **Slice 004's "a comma-separated chord cannot be typed into this dialog"** — the limitation is
  gone: the field has its own box, so `10,12,12,11,10,10` now reaches the parser intact. **Reinstated
  as a positive check** in the slice 007 section, since what was impossible is now expected to work.
- **Slice 005's "a name with a comma still round-trips"** — **live again**: the name has a field.
  It no longer exercises `dialog.prompt`'s rejoin, which is deleted, so it is now purely a check on
  the storage escaping.
- Every slice 004 check that needs a high-position chord (`x79987`, `10-12-12-11-10-10`,
  `12-14-14-13-12-12`) is **easiest typed again** rather than clicked in from its lowest fretted
  note. Do them that way.

## Slice 007 — the text field, the name field and the fret override

Version 0.10.0. Three controls above the grid: a chord string synced both ways with it, a free-text
name, and the first fret of the window. Nothing here has been run either — REAPER is still not
installed on the dev machine, and this slice adds three ReaImGui calls that have never executed.

### The new API names

`InputText`, `InputInt` and `IsAnyItemActive` are added to the checked list in
`src/adapter/imgui.lua`. As with slice 006, a name this code got wrong reports itself BY NAME at
load time — "This version of ReaImGui does not provide *name*" — rather than failing mid-frame.
**If that message appears, note which name and the ReaImGui version**; the fix is local to that
module.

### Confirm on Windows

- [ ] **Typing redraws the grid on every keystroke.** Type `x32010` into the Chord field one
      character at a time. The diagram must follow along, and the intermediate states (`x`, `x3`,
      `x32`…) must simply leave the last complete shape on screen — no error, no flicker, no
      window that closes itself.
- [ ] **Half-typed and nonsense text changes nothing and says nothing.** Type `x3201z`, then clear
      the field entirely. The diagram must hold the last shape that parsed, and no message may
      appear. This is deliberate: half-typed input is the normal state of a field somebody is
      typing into. Say if the silence feels wrong in practice.
- [ ] **Clicking the grid rewrites the chord string.** Click a shape in from scratch and watch the
      field fill itself in. This is how a guitarist learns the string for a shape they only know
      with their hands.
- [ ] **The field is not rewritten under the cursor while typing.** Type `x-3-2-0-1-0`, slowly. It
      must stay exactly as typed even though the chord it means is written `x32010` — the field
      is only ever rewritten from the voicing by a CLICK on the grid, never mid-word. If characters
      vanish, get reordered, or the caret jumps to the end, that is the bug this rule exists to
      prevent and it is a real defect.
- [ ] **A comma-separated chord can now be typed.** `10,12,12,11,10,10` must produce the same
      diagram as `10-12-12-11-10-10`. Slice 004 could not do this because the native dialog ate
      the commas; the field has its own box, so it should now work.
- [ ] **The name is the diagram's title and the item's name.** Type a name, apply, and confirm it
      is drawn on the diagram AND shows on the item in the arrange view and the Media Item Manager.
- [ ] **A chord left unnamed is still titled with its own chord string.** That fallback survived
      the name field; it is now a default rather than the only route.
- [ ] **Renaming produces a NEW image file.** Apply a chord, reopen it, change only the name, apply
      again. `chord-diagrams/` must gain a second PNG and the item must show the new title
      immediately — the name is part of the fingerprint precisely so REAPER cannot show a stale
      title.
- [ ] **The first fret box fills itself in.** Type `x79987`. The box must read 7 and its label must
      say the value is automatic, and the diagram must show `7fr`.
- [ ] **Overriding it reframes the diagram and moves no fingers.** With `x79987` on screen, set the
      first fret to 5. The marker must read `5fr`, the dots must move down two cells, and the chord
      string must still read `x79987`. Applying must produce a diagram framed from the fifth.
- [ ] **Auto hands the framing back.** Press Auto and the box must return to 7 and the label to
      automatic. Until this slice there was no way to undo an override that still worked.
- [ ] **Escape inside a text field does not close the window.** Click into the Name field, type,
      press Escape. The window must stay open — Escape in a field means "undo what I typed", and
      losing the whole chord to it would be a defect. Escape with no field focused must still close
      the window, as in slice 006.
- [ ] **The window is tall enough.** It opens at 380x560 to make room for three rows of controls
      above the grid. If the grid is cramped or the Apply row needs scrolling at the default size,
      say so — `WINDOW_W`/`WINDOW_H` in `src/adapter/imgui.lua` is the one place to change it.

### Judgement calls to confirm

- [ ] **The first fret box refuses a value that cannot hold the shape, by doing nothing.** With
      `x79987` on screen (frets 7 to 9), nudge the box down to 4: the window 4–8 cannot show the
      ninth fret, so the value snaps straight back to what it was. The span is fixed at five, so
      there is no framing to offer — but a control whose arrows sometimes appear dead needs a
      guitarist's opinion. The alternative is to clamp to the nearest usable fret, which silently
      gives a framing that was not asked for. Say which reads better.
- [x] ~~**Typing merges rather than replaces — and this is the one to take seriously.**~~ **Live as
      of slice 008**, which renders the bar. The check is now written out in the slice 008 section
      below ("A barre survives an edit to the chord string"); do it there rather than here.

## Slice 008 — barres, entered by dragging

Version 0.11.0. **This is the slice with the one interaction that could not be tested at all on the
development machine.** Everything else this project does has either a spec or a shape on screen to
compare against; telling a click apart from a drag has neither, because REAPER is not installed
here. Read *The gesture* below before testing, so a misfire is reported as the specific thing it is.

One new ReaImGui name is used: `IsItemActive`. As before, if that name is wrong it reports itself
at load time — "This version of ReaImGui does not provide IsItemActive" — before the window opens.
Note the ReaImGui version if it appears.

### The gesture

Both gestures open the same way, with the mouse going down on a cell, so the line between them is:

* **Ended on the string it started on → a click.** Vertical wander does not matter, so a click that
  slides up or down its own string is still a click.
* **Ended on a DIFFERENT string of the same fret row → a drag**, and the bar spans from the string
  it started on to the string it ended on.

The fret is taken from the cell the drag started in and never moves, so wandering into another row
mid-drag leaves the bar where it was.

### Confirm on Windows

- [ ] **Dragging across the strings at a fret draws a bar over them.** Type `133211`, then press on
      the low E at the first fret, drag to the high E and release. Expect a solid bar with rounded
      ends running the width of the grid in the first cell, with the dots at frets 3, 3 and 2 still
      where they were.
- [ ] **Laying a bar moves no finger.** In the same chord, the three fingers ABOVE the bar must not
      drop to the first fret, and the chord string must still read `133211`. If the shape flattens,
      that is silent data loss and a real defect.
- [ ] **A partial barre spans only the strings dragged across.** Type `xx3211` and drag across the
      first fret from the B string to the high E only. The bar must stop at the B string and not
      reach the D or G strings. This is the common case, not an edge case.
- [ ] **Dragging the other way works the same.** High E to low E must give the same bar as low E to
      high E.
- [ ] **Clicking the bar takes it away**, leaving every dot where it was. This is the removal
      gesture; it is a click precisely because creating a barre needs the pointer to travel.
- [ ] **Dragging again across a barred fret redraws the bar** rather than stacking a second one on
      it — that is how a span drawn wrongly is corrected.
- [ ] **A barre at a high position sits in the right cell.** Type `x79987`, drag across the SEVENTH
      fret row (the first cell of the window, under the `7fr` marker) from the A string to the high
      E. The bar must land in that first cell, level with the dots on the A and high E, not
      seven cells down or off the diagram.
- [ ] **The bar is in the exported PNG exactly as it is on screen.** Apply and look at the item.
      Both are drawn from the same primitives — a rectangle plus a round cap at each end — so any
      difference in length or position is the preview/output drift the architecture exists to
      prevent, and is an issue rather than a tweak.
- [ ] **A barre survives an edit to the chord string.** THE ONE TO TAKE SERIOUSLY, carried over
      from slice 007. Build a barre chord, then nudge one string in the TEXT field — `133211` to
      `133214`. The bar must still be there after every keystroke. It is specced end to end
      (`spec/core/layout_spec.lua`, "keeps drawing the bar while the chord string beside it is
      retyped"), so a failure here is in the window rather than in the merge.
- [ ] **A barre survives apply and reopen.** Apply a barred chord, run the action on that item
      again, and the bar must be back on the grid. Then save, close and reopen the project and
      check once more. The storage format has carried barres since slice 005, so this needs no new
      format — it is the first time anything has been able to SEE one.
- [ ] **Two items with the same shape but different bars get different images.** Apply `133211`
      barred across all six strings to one item and the same chord barred across the top two to
      another. `chord-diagrams/` must gain two PNGs, not one.

### Judgement calls to confirm

- [ ] **Clicking the bar to remove it means those cells cannot place a dot while the bar is there.**
      A click on a cell the bar covers addresses the bar. The alternative was a modifier or the
      right mouse button, which is a gesture nothing else in this window uses and which nobody
      would find. Say whether reaching for a dot under a bar and losing the bar instead happens in
      practice.
- [ ] **Dragging on a blank neck draws a bar with no dots under it.** Laying a bar moves no finger,
      so a bar drawn on strings that are still muted shows a bar above six crosses, which looks
      odd. This is the price of the guarantee in the second check above — the alternative, fretting
      every string the bar covers, is what would flatten an F. If the empty state reads as broken,
      the fix is to fret only the strings that are currently MUTED, which is a rule in
      `core.voicing.setBarre` and a spec.
- [ ] **A drag across the row above the nut does nothing.** There are no barres above the nut, and
      making a sideways drag up there mute or ring several strings at once would be inventing a
      gesture nobody asked for. Confirm doing nothing is right rather than surprising.
- [ ] **A click near the midpoint between two strings does not accidentally draw a two-string
      bar.** This is the residual risk in telling a click from a drag: the press has to land about
      half a string gap off centre AND wobble across the boundary. If it happens in normal use, the
      fix is a minimum travel in pixels before a drag counts, in `grid()` in
      `src/adapter/imgui.lua`.

### For the slice 011 style pass

- [ ] **How the bar and the dots sit together.** The bar is a capsule exactly as thick as a dot,
      and the dots of the strings it covers are still drawn, on top of it. At this thickness the
      two coincide exactly, so the choice is invisible — it matters only if the style pass thins
      the bar, hollows it, or gives it a different ink, at which point the dots underneath become
      visible again. Decide then whether the dots under a bar should be suppressed. Suppressing
      them now would make the fretted strings disappear the day the bar changes shape.
- [ ] **The bar's ends.** Round caps, one dot-radius past the outermost string it covers, so a
      full barre overhangs the grid by the same amount a dot does. Confirm that reads as a finger
      rather than as a bar that has slipped off the neck.

## Slice 009 — errors, dependency checks and the diagnostic action

Version 0.12.0, and **the package now installs TWO actions**: `Chord Diagram` and
`Chord Diagram: copy diagnostics` (`Chord Diagram/chord_diagram_diagnostics.lua`).

**Do this section FIRST when working the queue**, before the slice 003–008 checks. Everything else
in this file is a check that produces a symptom; this is the thing that turns a symptom into a
report. Run the diagnostic action once at the start and paste its output into the notes, then again
after anything that fails.

### Packaging — for the orchestrator, not the tester

- [ ] **The second action needs an index entry.** `make index` was not run and nothing was pushed,
      per the standing brief. `chord_diagram_diagnostics.lua` carries a full ReaPack header
      (`@description Chord Diagram: copy diagnostics`, `@version 0.12.0`, `@about`, `@changelog`) so
      `reapack-index` should pick it up as a second package in the `Chord Diagram` category with no
      hand editing. Confirm it appears in `index.xml` and that ReaPack offers both actions.
- [ ] **Both actions need `src/` on the same terms.** The new script carries a COPY of the entry
      script's module bootstrap rather than sharing one — a module that finds the modules would have
      to be found first, and this action must still work on an install where the other one does not.
      Whatever `src/` layout the packaging decision settles on, both scripts see it identically.

### The one that decides whether the rest of the queue can be reported

- [ ] **THE DIAGNOSTIC ACTION RUNS AND ITS OUTPUT IS ON THE CLIPBOARD.** Run it, paste the result.
      Expect a report with four sections — Versions, Paths, State, Last error. If nothing reaches
      the clipboard the report is still printed to the ReaScript console (Actions > Show console
      output), and the message box says which of the two happened. **Say which one you got.**

      The clipboard goes through SWS's `CF_SetClipboard` if SWS is installed, and otherwise through
      ReaImGui's `SetClipboardText`, which needs a context this action creates without ever opening
      a window. ReaImGui's source says that call has no frame guard and that an unused context
      disposes of itself, so this should be legal — but it has never been run. **If the console
      fallback fires on a machine that has ReaImGui, that is the interesting failure**, and the
      lines to look at are `viaImGui` in `src/adapter/clipboard.lua`.

### Confirm on Windows

- [ ] **Every refusal says the right thing.** Five cases, each of which must leave the item exactly
      as it was and add nothing to the undo stack:
      no item selected; three items selected (must say "3 are selected", not "that is not an empty
      item"); one audio or MIDI item selected; an unsaved project; and — if you can arrange it — an
      extension uninstalled.
- [ ] **Two audio items selected complains about the COUNT, not the type.** This is the ordering the
      old code got wrong and the reason the decision moved into `core.preflight`.
- [ ] **The last error in the report is the message you just saw.** Trigger any refusal, then run
      the diagnostic action: the Last error line must be that message with the timestamp of when it
      happened. It persists across a REAPER restart, so an error from a previous session shows up
      with an old timestamp rather than vanishing — that is deliberate, but say if it confuses.
- [ ] **The report names the ReaImGui version.** The Versions line should read something like
      `ReaImGui  0.9.3.2 (versioned binding, API 0.9 requested, Dear ImGui 1.89.9)`. This is the
      fact every slice since 006 has asked for and never got. **Record it in the queue notes even if
      everything works.**
- [ ] **The Paths section resolves to real files.** In particular `Modules` — which of the two
      candidate `src/` roots ReaPack actually installed to — and `ReaImGui shim`. A path that reads
      `unknown` where a file should be is a packaging failure, not a diagnostic one.
- [ ] **"Would run now" agrees with what the action does.** With one empty item selected it says
      `yes`; with nothing selected it says `no` and the refusal. It is computed by the same function
      the action refuses with, so a disagreement is a real defect.

### Version floors — the numbers that could not be checked here

- [ ] **REAPER 6.44 is the right floor.** `core.version.MIN_REAPER` refuses anything older, and the
      number is inherited from ReaImGui's own stated host requirement rather than measured: REAPER
      is not installed on the development machine. **The failure to watch for is it being too HIGH**
      — a working install refused with "This action needs REAPER 6.44 or newer". If the tester's
      REAPER is 7.x this check proves nothing, so it stays open; if anyone reports the refusal on a
      REAPER that runs ReaImGui fine, lower it.
- [ ] **js_ReaScriptAPI has NO version floor, by choice.** It is checked function by function
      instead — `JS_LICE_CreateBitmap`, `JS_LICE_Clear`, `JS_LICE_FillRect`, `JS_LICE_FillCircle`,
      `JS_GDI_CreateFont`, `JS_LICE_CreateFont`, `JS_LICE_SetFontFromGDI`, `JS_LICE_DrawText`,
      `JS_LICE_WritePNG`, the list `adapter.lice` calls unguarded — because a version number would
      have been invented on a machine that cannot run REAPER, whereas the list can be read off the
      code. A missing one is named in the refusal. Confirm the report's `js_ReaScriptAPI` version
      line is populated at all: it comes from `JS_ReaScriptAPI_Version()`, which is guarded and will
      read "installed, version unknown" if that name is wrong.

### The failure nobody can stage — read before deciding it is fine

- [ ] **A write that half-succeeds is rolled back.** If `SetItemStateChunk` succeeds and the
      extended-state write then fails, the item would carry the new diagram and the old voicing —
      the one state the design forbids, since the item's data is the source of truth and the PNG is
      a derivative. `adapter.item.writeChord` now puts the original chunk back and says so. **There
      is no way to make REAPER refuse that second write on purpose**, so this is verified only by a
      throwaway harness on the dev machine. If a user ever reports "the chord could not be attached
      to the item", the item should be exactly as it was; check that rather than the mechanism.
- [ ] **`asUndoableEdit` now wraps its work in a pcall** so `Undo_EndBlock` always runs. An error
      between begin and end would otherwise leave an undo block open for the rest of the session,
      quietly collecting the user's next edits under a chord's label. Nothing to test directly;
      noted so a later slice does not "simplify" the pcall away.

### Judgement calls to confirm

- [ ] **The last error is never cleared on success.** An intermittent failure the user got past on
      the second try is exactly the one worth reporting, so a successful run does not erase it; the
      timestamp is what says whether the error is the one being described. The cost is that a report
      run weeks later still carries an old error. Say if that reads as alarming rather than as
      history.
- [ ] **A host that will not report its version is allowed to run.** `GetAppVersion` failing is
      treated as unknown rather than as too old, on the grounds that a reporting gap must not become
      a plugin that refuses to start. The report says `unknown` on that line.
- [ ] **The report includes the raw stored voicing** of the selected item (`Chord on item`). It is
      the encoded token, not a chord string — it is there because it is the fact that says whether
      persistence worked, and it decodes by eye. Say if it is noise.

---

## Slice 010 — diagram recovery

Version 0.13.0, and **the package now installs THREE actions**: `Chord Diagram`,
`Chord Diagram: copy diagnostics`, and the new `Chord Diagram: regenerate missing diagrams`
(`Chord Diagram/chord_diagram_regenerate.lua`).

None of this could be run here: REAPER is not on the development machine, so every check below is a
first execution. **The sweep writes to items across the whole project** — do the first run of it on
a throwaway copy of a project, not on anything the tester cares about.

### Packaging — for the orchestrator, not the tester

- [ ] **The third action needs an index entry.** `make index` was not run and nothing was pushed,
      per the standing brief. `chord_diagram_regenerate.lua` carries a full ReaPack header
      (`@description Chord Diagram: regenerate missing diagrams`, `@version 0.13.0`, `@about`,
      `@changelog`) in the same shape as the other two, so `reapack-index` should pick it up as a
      third package in the `Chord Diagram` category. Confirm all three appear in `index.xml` and
      that ReaPack offers all three actions.
- [ ] **All three actions need `src/` on the same terms.** The new script carries a COPY of the
      module bootstrap, for the same reason the diagnostics one does. It also requires
      `src/adapter/diagram.lua` and `src/core/recovery.lua`, both new this slice.

### The two behaviours, in order

- [ ] **Silent repair on open.** Make a chord on an empty item and confirm the diagram shows. Delete
      that one PNG from `chord-diagrams/` in the project folder. Run `Chord Diagram` on the item
      again. **The image should be back and displayed by the time the window is open**, with no
      message of any kind, and the grid should show the chord as before. Then Cancel and confirm the
      item still displays the diagram.
- [ ] **THE MOST UNCERTAIN THING IN THE SLICE: does REAPER re-read a file it already failed to
      load?** The repair rewrites the item's state chunk after rendering, on the theory that setting
      the chunk again makes REAPER look for the resource a second time. Nobody has been able to test
      that here. **If the rebuilt diagram does not appear until the project is closed and reopened,
      say so** — the fix is a different nudge (`UpdateItemInProject`, or clearing `RESOURCEFN` and
      setting it back in two writes), not a different design, and the voicing is safe either way.
- [ ] **The whole folder.** Delete the entire `chord-diagrams/` folder from a project with several
      chords in it. Run `Chord Diagram: regenerate missing diagrams` with nothing selected. It
      should recreate the folder, rebuild every diagram, and report the count. Confirm every item
      displays its diagram again and that they are the RIGHT diagrams — same chord on the same item,
      not shuffled.
- [ ] **One Ctrl+Z undoes the whole sweep**, not one item at a time. Check the undo history shows a
      single "Chord diagram: regenerate missing diagrams" entry.
- [ ] **Nothing missing, nothing written.** Run the action again immediately. It should report
      "No diagrams needed regenerating" with the number of chords it checked, and — worth checking —
      **should NOT add an undo point**, since it opens no undo block when there is no work.
- [ ] **A project with no chords at all** answers "No chords found in this project" rather than
      counting to zero, and a project with audio and MIDI items mixed in is unaffected by the sweep.
- [ ] **Items with no chord are skipped, not errored.** Most items in a real project carry nothing.
      Run the sweep on a real project of the tester's and confirm it is quick, quiet, and changes
      nothing it should not.

### The new API calls — unconfirmed signatures

- [ ] **`reaper.CountMediaItems(0)` and `reaper.GetMediaItem(0, i)`** are the only calls this slice
      adds, both in `adapter.item.allItems`. They are the project-wide equivalents of the selection
      calls already proven, and nothing else in the sweep is new. If the action errors immediately
      with nothing happening, these are the first suspects.

### Judgement calls to confirm

- [ ] **The sweep visits EVERY item, not only empty ones.** It decides what to do from what an item
      carries rather than from what kind of item it is, so a chord that has somehow ended up on an
      item with a take is still repaired. The alternative — filtering to empty items — would drop
      that data silently and report a smaller number than the truth. Say if a chord on a non-empty
      item ever turns up and this reads as wrong.
- [ ] **The sweep requires ReaImGui even though it never opens a window.** It shares
      `core.preflight`'s installation checks with the editor so the two cannot disagree about what a
      working install is. The cost is that a machine with js_ReaScriptAPI but no ReaImGui is refused
      a recovery it could technically perform. The alternative is per-action dependency lists, which
      is more machinery than the case seems to warrant — but if a tester ever hits it on a fresh
      machine, that is the fix.
- [ ] **A failure part way through does not stop the sweep.** Each item is repaired atomically and
      the ones that worked stay fixed; the count of failures is reported and every reason is
      recorded for the diagnostics action. Stopping at the first failure would leave the rest of an
      already-broken project broken. Confirm the wording reads as honest rather than alarming.
- [ ] **A silent repair that fails stays silent.** It is recorded for the diagnostics action but no
      message is shown, because the user asked to edit a chord and can still do that — Apply renders
      through the same path and reports properly. Say if a silent failure feels like the wrong
      trade.
- [ ] **The sweep records damaged chords to the last-error slot.** A project containing one
      unreadable chord will leave an error behind in the diagnostic report even though the sweep
      itself succeeded. Consistent with "nothing clears the last error", but say if it reads as a
      failure that did not happen.

---

## Packaging and delivery — do this one FIRST

Every release before 0.14.0 shipped the action scripts **without** the modules under `src/`, so a
fresh install failed on its first `require`. If the tester has an older install, that is why.

Version 0.14.0 makes the whole plugin one ReaPack package: `chord_diagram.lua` is the package, and
its `@provides` header carries the other two actions and the whole of `src/` with it. The modules
are retargeted into the package's own folder, so an installed copy should look like this:

```
<REAPER resource path>/Scripts/<repository name>/Chord Diagram/
    chord_diagram.lua
    chord_diagram_diagnostics.lua
    chord_diagram_regenerate.lua
    src/core/*.lua        (7 files)
    src/adapter/*.lua     (9 files)
```

Find the resource path with **Options → Show REAPER resource path in explorer/finder**.

### The install itself

- [ ] **A FRESH import, not a synchronise.** In ReaPack, remove any existing *Chord Diagram*
      repository first (**Extensions → ReaPack → Manage repositories**, select it, **Remove**), then
      **Import repositories** with
      `https://github.com/tomtrembling/reaper-chord-diagram/raw/main/index.xml`. A stale local copy
      of the index is the thing most likely to make this look broken when it is not.
- [ ] **Exactly ONE package appears** in **Browse packages**, called *Chord Diagram*, at version
      **0.14.0**. The old *Chord Diagram (spike)* package must be **gone** — it has been removed from
      the index. If ReaPack lists it as obsolete and offers to uninstall it, accept.
- [ ] **All three actions appear** in **Actions → Show action list** after installing that one
      package. Search `chord_diagram`. Expect three entries, not one.
- [ ] **Note the exact names REAPER shows them under** and report them back. The README currently
      lists both the filename and the `@description` because which of the two REAPER displays for a
      ReaPack-installed script was never confirmed on a running install. If it shows filenames only,
      the README table should drop the descriptions.
- [ ] **The modules landed where the scripts look for them.** Open the resource path and confirm the
      `src/core/` and `src/adapter/` folders are inside the `Chord Diagram` folder, alongside the
      three scripts, with 7 and 9 `.lua` files in them. If they are instead a level ABOVE — beside
      the `Chord Diagram` folder rather than inside it — the plugin will still run (both locations
      are on `package.path`), but say so, because it means ReaPack resolved the install target
      differently from the way `reapack-index` wrote it and the retarget can be dropped.
- [ ] **Each of the three actions runs without a `require` error.** Running any of them and getting
      `module 'core.voicing' not found` — or any other `module ... not found` — means the modules did
      not install. That is the whole point of this release; report it immediately and do not work
      through the rest of the queue.
- [ ] **Start with the diagnostics action.** It is the one with no preconditions: nothing needs to be
      selected and it changes nothing. If it produces a report, the modules loaded. Keep that report
      — it names the resolved paths, which answers the previous two items on its own.

### The update path

- [ ] **A synchronise from an older install also works.** On a machine that already had 0.13.0 (or
      the spike), run **Extensions → ReaPack → Synchronise packages** rather than a fresh import, and
      confirm it pulls 0.14.0 and its modules. Fresh imports and updates take different code paths in
      ReaPack, and the tester's real machines will be doing the second one from now on.
- [ ] **Uninstalling takes everything with it.** Uninstall *Chord Diagram* in ReaPack and confirm the
      `src/` folders go too, leaving no orphaned files. The modules were deliberately retargeted
      inside the package's folder so that this works; if anything is left behind, say what.

### Decisions to confirm or overturn

- [ ] **The spike is no longer shipped.** `chord_diagram_spike.lua` moved to `ref/` and carries
      `@noindex`, so it is neither offered nor installed. The reasoning: it was superseded at 0.6.0,
      its findings are recorded in issue 002 and in its own header, and a second package called
      *Chord Diagram (spike)* sitting next to the real one in the tester's package list is an
      invitation to install the wrong one. It is still in the repository as the reference
      implementation of the REAPER call sequences it proved. Overturn this if the spike is still
      wanted as something the tester can run.
- [ ] **One package rather than three.** The alternative was three packages, one per action, each
      providing the modules — which `reapack-index` rejects: two packages claiming the same file is a
      conflict, and it resolves the conflict by silently dropping a package from the index while
      still exiting 0. One package also means the tester installs once and the three actions can
      never be at different versions. The cost is that the three actions cannot be installed
      separately, which nobody has asked for.
