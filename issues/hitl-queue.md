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
- [ ] **Judgement call: high-position chords are unlabelled until slice 004.** Enter `x79987`. The
      diagram frames itself from the seventh fret, but the marker that says "7fr" is slice 004, so
      until then the shape is drawn without saying where on the neck it is. Confirm that is
      acceptable in the interim, or bring 004 forward.

### Packaging — for the orchestrator, not the tester

- [ ] **Decide how `src/` reaches the installed script.** The plugin is no longer one file. The
      entry script puts both `<script dir>/src` and `<script dir>/../src` on `package.path`, so
      either layout works: ReaPack can install the modules beside the script, or one directory up.
      Nothing was changed in `index.xml` and `make index` was not run.

## Slice 005 — persistence and round-trip editing

The voicing is now stored on the item as one line in its state chunk:

```
CHORDDIAGRAM v1;s=6;f=-1,3,2,0,1,0;g=0,0,0,0,0,0;b=;p=;n=Cadd9
```

One token, no whitespace and no quotes, everything else percent-escaped, versioned with `v1`.

### Blocking risk — confirm this first, the whole slice rests on it

- [ ] **Does REAPER preserve the `CHORDDIAGRAM` line across a project save and reload?**
      REAPER may discard item chunk lines it does not recognise when it rewrites the project file.
      Nothing on the dev machine can answer this. To check: apply a chord, save the project, close
      it, reopen it, and run the action on that item again. The chord and name must come back
      pre-filled in the dialog. Also open the `.RPP` in a text editor and confirm the
      `CHORDDIAGRAM` line is inside the `<ITEM` block.
      **If the line does not survive**, the fix is to keep the same encoded string but store it
      through REAPER's own item extension state —
      `reaper.GetSetMediaItemInfo_String(item, "P_EXT:chorddiagram", encoded, true)` to write and
      the same call with `false` to read — which is documented to persist and to follow a copied
      item. Only `src/adapter/item.lua` and the two `chunkOf` calls in the entry script change;
      `voicing.encode`/`decode` and their specs are unaffected, which is why the format and the
      storage mechanism were kept apart. Raise it as a new issue rather than patching in place.

### Confirm on Windows

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
      data is not keyed to item identity.
- [ ] **Ctrl+Z reverts an edit in one step**, restoring both the previous image and the previous
      stored voicing.
- [ ] **A name with a comma still round-trips.** Name a chord `C, second inversion` and reopen it.
      The dialog is comma-separated, so this exercises `dialog.prompt`'s rejoin as well as the
      storage escaping.

### Judgement call to confirm

- [ ] **A base-fret override survives a text edit.** Re-typing the chord string carries the previous
      override forward, because the text field cannot express one and dropping it would lose data
      on a pure rename. The cost is that retyping a completely different chord keeps an override
      that may now be nonsense. There is no UI to clear it until slice 004/006. The alternative —
      dropping the override whenever the frets change — silently discards an explicit choice, which
      seemed worse. Confirm, or reverse it in slice 004.
