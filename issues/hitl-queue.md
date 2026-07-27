# HITL queue — the one human pass

Ten AFK slices built this plugin without a human in the loop. Everything they could not verify
themselves is here, rewritten into one session for two people:

- **Part 1 — the developer** (macOS, cannot run REAPER). Judgement calls a slice made defensibly
  and flagged for review: visual choices, interaction choices, and one about the test fixtures.
  No REAPER needed. The tester does not need to read this part.
- **Part 2 — the tester** (Windows, the only machine that can run any of this). A script: do this,
  expect that, and if it is wrong, what it probably means. Worked top to bottom, in order.

The build under test is **0.14.0**, the first release that ships the modules under `src/`. Every
release before it installed the action scripts alone and failed on the first `require`.

## How to run this pass

**Developer, before the tester starts:**

1. `make verify` — all four checks green.
2. `index.xml` is already generated for 0.14.0 and committed (`daa1adc`). **Nothing has been
   pushed.** Push `main`: the tester's ReaPack import reads `index.xml` out of the repository, so
   nothing in Part 2 is reachable until it is on GitHub. Pushing publishes 0.14.0 to anyone who has
   imported the repository and withdraws the *Chord Diagram (spike)* package from their list.
3. Work Part 1 whenever — it needs nothing from the tester except the screenshots T43 brings back.

**Tester:** work Part 2 in order. It is a session, not a list: nothing is checkable without a
working install, so the install is first; the diagnostics report frames everything after it, so it
is second; the window opening decides whether most of the rest is reachable at all, so it is third.
Anything that fails becomes a new issue file rather than a patch in place, so the failure is
recorded. When something fails, run the diagnostics action again and paste the report with it.

**Markers:**

- **[BLOCKER]** — if this fails, stop and report. What follows it is unreachable or meaningless.
- **[record]** — bring the value back even if everything passes. These are the facts every slice
  since 006 has asked for and never got.
- **[prereq]** — not a check. Data to capture that a spec depends on; blocks no other item here.

---

# Part 1 — the developer

Judgement calls. Each one names the alternative and where the change would go, so the answer is
"keep" or a one-line edit. None of them needs REAPER; several are easier with T43's screenshots.

## Test fixtures

- [ ] **D1 — `spec/fixtures/item_chunks.lua` is reconstructed, not captured.** The PRD asks for
      real item state chunks for exactly this module, because a bad chunk write corrupts a user's
      item. The chunks were written from the documented format (ReaTeam's State Chunk Definitions)
      and the field order the spike's `withImage` was built against, because REAPER is not on the
      dev machine. A passing `core.chunk` spec therefore proves the transformation against the
      format *as documented*, not against what REAPER emits. One thing is deliberately absent
      rather than guessed: how REAPER serialises `P_EXT:chorddiagram` into the chunk — what
      protects that today is a spec saying an unrecognised line is carried through unchanged.
      **Decide whether to ship on reconstructed fixtures or hold until T42 returns real ones.**

## Entry and interaction

- [ ] **D2 — Clearing a dot returns the string to MUTED, not OPEN.** Clicking a dot off is a
      deletion, and muted is the state that claims nothing: a string is not sounded until the user
      says so above the nut. Clearing to open would silently add a ringing string to the diagram
      every time a finger is removed. Alternative is a one-line change in `core.voicing.toggleFret`
      plus a spec.
- [ ] **D3 — The first fret box refuses a value that cannot hold the shape by doing nothing.** With
      `x79987` (frets 7–9) on screen, nudging the box to 4 snaps it straight back: the window 4–8
      cannot show the ninth fret and the span is fixed at five. The cost is arrows that sometimes
      look dead. The alternative is clamping to the nearest usable fret, which silently gives a
      framing nobody asked for.
- [ ] **D4 — A click on a cell the bar covers removes the bar, so those cells cannot take a dot
      while it is there.** The alternative was a modifier or the right mouse button — a gesture
      nothing else in this window uses and nobody would find. The question is whether reaching for
      a dot under a bar and losing the bar instead happens in practice.
- [ ] **D5 — Dragging on a blank neck draws a bar with no dots under it.** Laying a bar moves no
      finger, so a bar over still-muted strings shows a bar above six crosses, which looks odd.
      That oddity is the price of the guarantee that laying a bar never flattens an F. If the empty
      state reads as broken, the fix is to fret only the strings currently MUTED, a rule in
      `core.voicing.setBarre` plus a spec. See T43's blank-neck screenshot.
- [ ] **D6 — A drag across the row above the nut does nothing.** There are no barres above the nut,
      and making a sideways drag up there mute or ring several strings at once invents a gesture
      nobody asked for. Confirm doing nothing is right rather than surprising.
- [ ] **D7 — The residual risk in telling a click from a drag.** A press has to land about half a
      string gap off centre AND wobble across the boundary to produce an accidental two-string bar.
      T21 asks the tester to say if it ever happens; if it does, the fix is a minimum travel in
      pixels before a drag counts, in `grid()` in `src/adapter/imgui.lua`. See Appendix A2 for
      where the boundary sits.
- [ ] **D8 — A high chord with an open string keeps the window rather than the nut.** `x-0-9-9-7-x`
      reaches the ninth fret, so the nut cannot be shown without putting dots off the diagram: it
      frames from the seventh and still draws an open ring above the A string. That is how
      songbooks notate it, but it is a call — does it read correctly, or like a mistake? Screenshot
      in T43.

## Diagnostics and reporting

- [ ] **D9 — The last error is never cleared on success.** An intermittent failure the user got
      past on the second try is exactly the one worth reporting, so a successful run does not erase
      it; the timestamp says whether the error is the one being described. The cost is that a
      report run weeks later still carries an old error. Alarming, or history?
- [ ] **D10 — A host that will not report its version is allowed to run.** `GetAppVersion` failing
      is treated as unknown rather than as too old: a reporting gap must not become a plugin that
      refuses to start. The report says `unknown` on that line.
- [ ] **D11 — The report includes the raw stored voicing** of the selected item (`Chord on item`) —
      the encoded token, not a chord string. It is there because it is the fact that says whether
      persistence worked, and it decodes by eye. Noise, or worth the line?

## The sweep

- [ ] **D12 — The sweep visits EVERY item, not only empty ones.** It decides what to do from what
      an item carries, not from what kind of item it is, so a chord that has somehow ended up on an
      item with a take is still repaired. Filtering to empty items would drop that data silently
      and report a smaller number than the truth.
- [ ] **D13 — The sweep requires ReaImGui even though it never opens a window.** It shares
      `core.preflight`'s installation checks with the editor so the two cannot disagree about what
      a working install is. The cost is that a machine with js_ReaScriptAPI but no ReaImGui is
      refused a recovery it could technically perform. The alternative is per-action dependency
      lists — more machinery than the case seems to warrant, but that is the fix if it ever bites.
- [ ] **D14 — A failure part way through does not stop the sweep,** and the failure count is
      reported separately rather than folded into the regenerated total. Stopping at the first
      failure would leave the rest of an already-broken project broken. Read the wording: honest,
      or alarming?
- [ ] **D15 — A silent repair that fails stays silent.** It is recorded for the diagnostics action
      but no message is shown, because the user asked to edit a chord and can still do that — Apply
      renders through the same path and reports properly. Right trade?
- [ ] **D16 — The sweep records damaged chords to the last-error slot,** so a project containing one
      unreadable chord leaves an error in the diagnostic report even though the sweep succeeded.
      Consistent with D9; does it read as a failure that did not happen?

## Packaging

- [ ] **D17 — The spike is no longer shipped.** `chord_diagram_spike.lua` moved to `ref/` with
      `@noindex`, so it is neither offered nor installed. It was superseded at 0.6.0, its findings
      are recorded in issue 002 and in its own header, and a second package called *Chord Diagram
      (spike)* next to the real one invites installing the wrong one. It stays in the repository as
      the reference implementation of the REAPER call sequences it proved. Overturn this if the
      tester should still be able to run it.
- [ ] **D18 — One package rather than three.** Three packages each providing `src/` is what
      `reapack-index` calls a conflict, and it resolves a conflict by silently dropping a package
      from the index while still exiting 0. One package also means the tester installs once and the
      three actions can never be at different versions. The cost is that the actions cannot be
      installed separately, which nobody has asked for.
- [ ] **D19 — The README lists both the filename and the `@description` for all three actions,**
      because which of the two REAPER shows for a ReaPack-installed script has never been seen on a
      running install. T2 brings back the answer; if it shows filenames only, drop the descriptions
      from the README table.

## For the slice 011 style pass (issues/011-visual-style-pass.md)

- [ ] **D20 — How the bar and the dots sit together.** The bar is a capsule exactly as thick as a
      dot, and the dots of the strings it covers are still drawn, on top of it. At this thickness
      the two coincide exactly, so the choice is invisible — it matters only if the style pass
      thins the bar, hollows it, or gives it a different ink, at which point the dots underneath
      become visible again. Suppressing them now would make the fretted strings disappear the day
      the bar changes shape.
- [ ] **D21 — The bar's ends.** Round caps, one dot-radius past the outermost string it covers, so
      a full barre overhangs the grid by the same amount a dot does. Does that read as a finger, or
      as a bar that has slipped off the neck?

---

# Part 2 — the tester

Windows. Work down in order. Each item says what to expect and, where it matters, what a wrong
answer means. Appendices at the end carry the detail for diagnosing a failure — do not read them
until something fails.

## 1. Install — nothing below works without this

Find the resource path with **Options → Show REAPER resource path in explorer/finder**. An
installed copy should look like:

```
<REAPER resource path>/Scripts/<repository name>/Chord Diagram/
    chord_diagram.lua
    chord_diagram_diagnostics.lua
    chord_diagram_regenerate.lua
    src/core/*.lua        (7 files)
    src/adapter/*.lua     (10 files)
```

- [ ] **T1 [BLOCKER] A FRESH import, not a synchronise.** In ReaPack, remove any existing *Chord
      Diagram* repository first (**Extensions → ReaPack → Manage repositories**, select it,
      **Remove**), then **Import repositories** with
      `https://github.com/tomtrembling/reaper-chord-diagram/raw/main/index.xml`. A stale local copy
      of the index is the thing most likely to make this look broken when it is not. In **Browse
      packages**, expect **exactly one** package, *Chord Diagram*, at version **0.14.0**. The old
      *Chord Diagram (spike)* must be **gone**; if ReaPack lists it as obsolete and offers to
      uninstall it, accept.
- [ ] **T2 [BLOCKER] [record] All three actions appear.** Install that one package, then
      **Actions → Show action list** and search `chord_diagram`. Expect three entries, not one.
      **Write down the exact names REAPER shows them under** — filenames, or the descriptions
      (*Chord Diagram*, *Chord Diagram: copy diagnostics*, *Chord Diagram: regenerate missing
      diagrams*). Nobody has ever seen which it is.
- [ ] **T3 [BLOCKER] The modules landed where the scripts look for them.** Open the resource path
      and confirm `src/core/` (7 `.lua` files) and `src/adapter/` (10 `.lua` files) are **inside**
      the `Chord Diagram` folder, alongside the three scripts. If they are instead a level ABOVE —
      beside the `Chord Diagram` folder rather than inside it — the plugin still runs (both
      locations are on `package.path`), but say so: it means ReaPack resolved the install target
      differently from the way `reapack-index` wrote it, and the retarget can be dropped.
- [ ] **T4 [BLOCKER] Each of the three actions runs without a `require` error.** `module
      'core.voicing' not found` — or any other `module ... not found` — means the modules did not
      install. That is the entire point of this release: report it immediately and do not work
      through the rest of the queue.

## 2. Diagnostics — run this before anything else, and again after every failure

- [ ] **T5 [BLOCKER] [record] The diagnostics action runs and its report reaches the clipboard.**
      Run *Chord Diagram: copy diagnostics* with nothing selected — it has no preconditions and
      changes nothing. Paste the result somewhere and keep it. Expect four sections: Versions,
      Paths, State, Last error.
      - **Say whether it reached the clipboard or fell back to the ReaScript console** (the message
        box says which). The clipboard goes through SWS's `CF_SetClipboard` if SWS is installed and
        otherwise through ReaImGui's `SetClipboardText`, which needs a context this action creates
        without ever opening a window. **A console fallback on a machine that HAS ReaImGui is the
        interesting failure** — the lines to look at are `viaImGui` in `src/adapter/clipboard.lua`.
      - **[record] the ReaImGui version line.** Expect something like
        `ReaImGui 0.9.3.2 (versioned binding, API 0.9 requested, Dear ImGui 1.89.9)`.
      - **[record] the REAPER version.** The floor is 6.44 and was inherited, not measured — see A6.
      - **The `js_ReaScriptAPI` line must be populated at all.** "installed, version unknown" means
        `JS_ReaScriptAPI_Version()` is the wrong name; not fatal, but say so.
      - **The Paths section must resolve to real files**, in particular `Modules` (which `src/` root
        ReaPack actually installed to — this answers T3 on its own) and `ReaImGui shim`. `unknown`
        where a file should be is a packaging failure, not a diagnostic one.

## 3. The window opens

Everything after this needs the window. Set up a **saved** project with one empty item on a track,
and select it.

- [ ] **T6 [BLOCKER] THE WINDOW OPENS.** Run *Chord Diagram*. Expect a window at 380x560 with three
      rows of controls above a fretboard grid, and an Apply row that does not need scrolling to
      reach. If it does not open, or opens cramped, **go to Appendix A1** — the ReaImGui binding is
      a guess made from documentation rather than from a running REAPER, and A1 turns each symptom
      into a specific cause. If the default size is wrong, `WINDOW_W`/`WINDOW_H` in
      `src/adapter/imgui.lua` is the one place to change it.
- [ ] **T7 The window can be resized and the grid follows.** The grid is recomputed from the
      window's available space every frame, so it should stay square and stay clickable at any
      size. Drag it small: below a floor the grid stops shrinking and the buttons scroll, which is
      intended.

## 4. Typing a chord

- [ ] **T8 Typing redraws the grid on every keystroke.** Type `x32010` into the Chord field one
      character at a time. The diagram must follow along, and the intermediate states (`x`, `x3`,
      `x32`…) must simply leave the last complete shape on screen — no error, no flicker, no window
      that closes itself. Finished, expect: a cross above the nut on the low E, dots at frets 3, 2
      and 1 on the A, D and B strings, open rings above the nut on the G and high E.
- [ ] **T9 Half-typed and nonsense text changes nothing and says nothing.** Type `x3201z`, then
      clear the field entirely. The diagram holds the last shape that parsed, and **no message may
      appear** — half-typed input is the normal state of a field somebody is typing into. Say if the
      silence feels wrong in practice.
- [ ] **T10 The field is not rewritten under the cursor while typing.** Type `x-3-2-0-1-0`, slowly.
      It must stay exactly as typed even though the chord it means is written `x32010` — the field
      is only ever rewritten from the voicing by a CLICK on the grid, never mid-word. Characters
      vanishing, reordering, or the caret jumping to the end is a real defect.
- [ ] **T11 The separated forms both work and round-trip.** `10-12-12-11-10-10` and
      `10,12,12,11,10,10` must give the same diagram: a `10fr` marker and a barre-shaped block of
      dots. Apply, reopen the item, and the field must come back as typed —
      `10-12-12-11-10-10`, not `101212111010`.
- [ ] **T12 A high-position chord frames and labels itself.** Type `x79987`. Expect no heavy nut
      line, a `7fr` marker in the gutter to the LEFT of the grid, level with the first fret cell,
      and dots in cells 1, 3, 3, 2, 1 across the A, D, G, B and high E. The first fret box must fill
      itself in with 7, and its label must say the value is automatic.
- [ ] **T13 Overriding the first fret reframes the diagram and moves no fingers, and Auto hands it
      back.** With `x79987` on screen, set the first fret to 5: the marker reads `5fr`, the dots
      move down two cells, and the chord string still reads `x79987`. Applying produces a diagram
      framed from the fifth. Then press Auto: the box returns to 7 and the label to automatic.
- [ ] **T14 The fret marker is legible and does not collide with the grid.** This is the one piece
      of geometry never tuned by eye — the gutter left of the grid was empty until slice 004. Look
      at the widest text that has to fit: `12-14-14-13-12-12`. Clipped, cramped, or hard against
      the left edge of the image is a real defect; the marker's size is `POSITION_HEIGHT` in
      `src/core/layout.lua`.

## 5. Clicking the grid

- [ ] **T15 A click lands on the cell it appears to land on.** Click the third fret of the A string:
      the dot appears under the pointer, not one cell out. Check the top and bottom cells and both
      outer strings especially — an off-by-one in the hit test shows at the edges first. The round
      trip is specced (`spec/core/layout_spec.lua`), but only against the specs' idea of where the
      mouse is; this confirms ImGui's idea agrees.
- [ ] **T16 Clicking a cell places a dot and clicking it again removes it,** leaving that string
      MUTED (a cross above the nut), not open. Deliberate — see D2.
- [ ] **T17 Clicking above the nut toggles a string between open and muted,** and clicking above the
      nut on a string that has a dot lifts the dot and rings the string open.
- [ ] **T18 Clicking the grid rewrites the chord string.** Click a shape in from scratch and watch
      the field fill itself in. This is how a guitarist learns the string for a shape they only
      know with their hands.

## 6. Barres, entered by dragging

Read **Appendix A2** first — it says exactly where the line between a click and a drag sits, so a
misfire gets reported as the specific thing it is.

- [ ] **T19 Dragging across the strings at a fret draws a bar, and moves no finger.** Type `133211`,
      press on the low E at the first fret, drag to the high E, release. Expect a solid bar with
      rounded ends running the width of the grid in the first cell. The three fingers ABOVE the bar
      must not drop to the first fret, and the chord string must still read `133211`. **If the
      shape flattens, that is silent data loss and a real defect.**
- [ ] **T20 A partial barre spans only the strings dragged across, in either direction.** Type
      `xx3211` and drag across the first fret from the B string to the high E only: the bar stops
      at the B string and does not reach the D or G. This is the common case, not an edge case.
      Dragging high E to low E must give the same bar as low E to high E.
- [ ] **T21 Clicking the bar takes it away, and dragging again redraws it.** A click on the bar
      removes it, leaving every dot where it was — removal is a click precisely because creating a
      barre needs the pointer to travel. Dragging again across a barred fret must redraw the bar
      rather than stack a second one on it; that is how a span drawn wrongly is corrected. **If an
      ordinary click ever produces a two-string bar by accident, say so** (see A2).
- [ ] **T22 A barre at a high position sits in the right cell.** Type `x79987` and drag across the
      SEVENTH fret row — the first cell of the window, under the `7fr` marker — from the A string
      to the high E. The bar must land in that first cell, level with the dots on the A and high E,
      not seven cells down or off the diagram.
- [ ] **T23 A barre survives an edit to the chord string. THE ONE TO TAKE SERIOUSLY.** Build a barre
      chord, then nudge one string in the TEXT field: `133211` to `133214`. The bar must still be
      there after every keystroke. It is specced end to end (`spec/core/layout_spec.lua`, "keeps
      drawing the bar while the chord string beside it is retyped"), so a failure here is in the
      window rather than in the merge.

## 7. Apply, reopen, undo, persist

- [ ] **T24 Apply writes the chord and closes the window in one press, and the item shows the
      diagram.** In the arrange view, on Windows — the path stored in the item is a forward slash
      rather than the platform separator so that a project made on Windows opens on macOS, and this
      is where that gets confirmed. **The exported PNG must match what was on screen**: same
      spacing, same dot positions, same fret for every dot, and a bar of the same length in the
      same place. Both are drawn from the same primitives, so any *geometry* difference is the
      preview/output drift this architecture exists to prevent — raise it as an issue. Two
      non-geometry differences are expected and are not bugs; see **A3**.
- [ ] **T25 The name is the diagram's title and the item's name.** Type a name, apply, and confirm
      it is drawn on the diagram AND shows on the item in the arrange view and in **View → Media
      Item Manager**. Then do it once with a comma in the name — `C, second inversion` — and reopen
      the item: the name must come back intact, which is the check on the storage escaping. If the
      Item Manager does not surface the name at all, see **A4**.
- [ ] **T26 A chord left unnamed is still titled with its own chord string.** That fallback survived
      the name field; it is now a default rather than the only route.
- [ ] **T27 Is the title centred?** `JS_LICE_DrawText` is given the full width of the canvas as its
      box, and whether LICE centres text inside a box or puts it hard against the left edge has
      never been seen. Look at both the title and the `7fr` marker in an exported PNG, and compare
      them with the same two on screen. **If the window centres them and the PNG does not, that is
      a known asymmetry with a known fix — see A5.**
- [ ] **T28 Cancel and Escape leave the item exactly as it was.** Cancel closes the window with no
      new PNG in `chord-diagrams/`, no change to the item, and nothing on the undo stack to press
      Ctrl+Z through. Escape with no field focused does the same (the window must have focus for
      ImGui to see the key — that is correct, not a bug). **Escape while a text field is focused
      must NOT close the window**: there it means "undo what I typed", and losing the whole chord
      to it would be a defect.
- [ ] **T29 Reopening an item pre-fills everything.** Run the action again on an item that already
      carries a chord: the grid, the chord string, the name and the first fret must all come back
      as they were, including a barre, and the window's diagram must carry the name that chord
      already had. The storage format has carried barres since slice 005, but this is the first
      release that can SEE one.
- [ ] **T30 Ctrl+Z reverts a chord in one step**, like any other REAPER edit — both a brand new
      chord and an edit to an existing one, restoring the previous image and the previous stored
      voicing together. Two REAPER writes happen inside the undo block (the state chunk, then the
      extended state), so this also confirms they collapse into a single undo point rather than
      needing two presses.
- [ ] **T31 One file per distinct diagram, and never a stale one.** The filename is a hash of the
      voicing *and* the name, which is what makes all of this true at once:
      - Apply the same chord and name to two empty items: `chord-diagrams/` holds exactly **one**
        PNG and both items show it.
      - Change the chord (`x32010` → `x32013`), or change only the name, or barre one copy and not
        the other: each gives a **new** PNG, and the item must show the new diagram **immediately**
        — no stale picture. This is the caching behaviour the hashed filename exists to sidestep,
        so it is the interesting one.
      - On the rename in particular: the shape must be **identical** and only the title different.
- [ ] **T32 Two runs in a row do not leave a window behind.** The lifecycle is one-shot: the loop
      stops deferring after Apply, Cancel or Escape, and ReaImGui destroys a context that stops
      being used. If a ghost window survives, say so — the pre-0.9 fallback path had an explicit
      `DestroyContext` that the current API removed, and this code deliberately calls neither.
- [ ] **T33 A chord survives save, close and reopen.** Apply a chord (barre one of them), save the
      project, close it, reopen it, and run the action on that item again: the chord, the barre and
      the name must come back pre-filled. **This is the one assumption the storage design rests
      on** — that REAPER saves per-item extended state with the project. A failure here is a real
      defect; raise a new issue rather than patching in place.
- [ ] **T34 Copying an item carries the chord.** Copy an item with a chord, paste it elsewhere, and
      run the action on the copy: it must pre-fill with the same voicing. This proves the data is
      not keyed to item identity. That REAPER duplicates a `P_EXT:` value along with the item could
      not be confirmed from documentation on the dev machine, so it is checked rather than assumed.
      If the copy comes up blank, see **A4** for the fallback and raise it as an issue.

## 8. Refusals

- [ ] **T35 Every refusal says the right thing.** Six cases. Each must leave the item exactly as it
      was and add **nothing** to the undo stack:
      1. no item selected;
      2. three items selected — must say "3 are selected", **not** "that is not an empty item";
      3. **two AUDIO items selected — must still complain about the COUNT, not the type.** This is
         the ordering the old code got wrong and the reason the decision moved into
         `core.preflight`;
      4. one audio or MIDI item selected;
      5. an unsaved project;
      6. if you can arrange it, an extension uninstalled.
      Then check the report agrees with the action: run diagnostics with nothing selected and
      **"Would run now"** must say `no` plus that refusal; with one empty item selected it must say
      `yes`. It is computed by the same function the action refuses with, so a disagreement is a
      real defect.
- [ ] **T36 The last error in the report is the message you just saw,** with the timestamp of when
      it happened. It persists across a REAPER restart, so an error from a previous session shows
      up with an old timestamp rather than vanishing. That is deliberate (D9) — say if it confuses.

## 9. Recovery and the sweep — last, and on a throwaway project

**The sweep writes to items across the whole project.** Do its first run on a throwaway copy of a
project, not on anything you care about.

- [ ] **T37 Silent repair on open — and the most uncertain thing in the build.** Make a chord on an
      empty item and confirm the diagram shows. Delete that one PNG from `chord-diagrams/` in the
      project folder. Run *Chord Diagram* on the item again. **The image should be back and
      displayed by the time the window is open**, with no message of any kind, and the grid should
      show the chord as before. Cancel, and the item must still display the diagram.
      **If the rebuilt diagram does not appear until the project is closed and reopened, say so** —
      that is the open question in **A6**, the voicing is safe either way, and the fix is a
      different nudge rather than a different design.
- [ ] **T38 The whole folder.** Delete the entire `chord-diagrams/` folder from a project with
      several chords in it. Run *Chord Diagram: regenerate missing diagrams* with nothing selected.
      It should recreate the folder, rebuild every diagram, and report the count. Confirm every
      item displays its diagram again and that they are the RIGHT diagrams — same chord on the same
      item, not shuffled.
- [ ] **T39 One Ctrl+Z undoes the whole sweep**, not one item at a time. The undo history must show
      a single "Chord diagram: regenerate missing diagrams" entry.
- [ ] **T40 Nothing missing, nothing written.** Run the sweep again immediately. It must report
      "No diagrams needed regenerating" with the number of chords it checked, and — worth checking
      — must **NOT** add an undo point, since it opens no undo block when there is no work.
- [ ] **T41 Projects it should not touch.** A project with no chords at all must answer "No chords
      found in this project" rather than counting to zero. Then run the sweep on a real project of
      yours with audio and MIDI items in it: it must be quick, quiet, change nothing it should not,
      and skip items carrying no chord rather than erroring on them.
      If the action errors immediately with nothing happening at all, see **A6**.

## 10. Bring back

- [ ] **T42 [prereq] Capture three real item state chunks.** Not a check — data the specs need.
      Select an item and run a one-line ReaScript:
      `local ok, c = reaper.GetItemStateChunk(reaper.GetSelectedMediaItem(0,0), "", false)
      reaper.ShowConsoleMsg(c)`.
      Do it for **an empty item** (→ `M.EMPTY_ITEM`), **an item that already carries a chord
      diagram** (→ `M.ITEM_WITH_CHORD`) and **an audio item** (→ `M.AUDIO_ITEM`), and send all
      three back to paste over `spec/fixtures/item_chunks.lua`. Until then, the `core.chunk` specs
      prove the transformation against the format as documented, not against what REAPER emits
      (D1). The chord capture answers a second question too: how REAPER serialises the item's
      extended state (`P_EXT:chorddiagram`, where the voicing lives) into the chunk — the encoded
      token should be visible somewhere in it. Once pasted in, re-run `make test`; **any failure is
      a real defect in `src/core/chunk.lua`, not in the test.**
- [ ] **T43 [record] Screenshots, for the developer's visual calls.** Six, so none of these needs a
      second pass: `x32010` applied to an item; `x79987` showing `7fr`; `x-0-9-9-7-x` (framed from
      the seventh with an open ring above the A string); `133211` with a full barre; `xx3211` with
      a partial barre on the top two strings; and a bar dragged across a blank, all-muted neck.
- [ ] **T44 A synchronise from an older install also works.** On a machine that already had 0.13.0
      or the spike, run **Extensions → ReaPack → Synchronise packages** rather than a fresh import,
      and confirm it pulls 0.14.0 **and its modules**. Fresh imports and updates take different code
      paths in ReaPack, and the real machines will be doing the second one from now on.
- [ ] **T45 Uninstalling takes everything with it. LAST — this removes the plugin.** Uninstall
      *Chord Diagram* in ReaPack and confirm the `src/` folders go too, leaving no orphaned files.
      The modules were deliberately retargeted inside the package's folder so that this works; if
      anything is left behind, say what.

---

# Appendix — only when something fails

## A1. The window will not open

The ReaImGui binding is the one part of this that was written from documentation rather than
against a running REAPER. ReaImGui changed how a script reaches it at version 0.9.
`src/adapter/imgui.lua` tries the current documented way first —

```lua
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'
```

— detected by whether `ImGui_GetBuiltinPath` exists, since that function arrived with the shim in
0.9. If it does not exist, the module falls back to the pre-0.9 style of calling `reaper.ImGui_*`
directly, building the same table by hand and calling the constant getters
(`reaper.ImGui_Key_Escape()`) that the newer API exposes as plain values. Everything else in the
project talks to that one table and cannot tell which style won.

| What you see | What it means |
| --- | --- |
| "This action needs ReaImGui" | ReaImGui is not installed at all. Install it via ReaPack. |
| "ReaImGui cannot provide API version 0.9" | The install predates 0.9 *and* the fallback was not taken — report the ReaImGui version. |
| "This version of ReaImGui does not provide *name*" | The fallback was taken and that install is too old for that call. **Report the name and the version** — the fix is local to `src/adapter/imgui.lua`. |
| "ReaImGui's shim could not be loaded" | `imgui.lua` is missing from `Scripts/ReaTeam Extensions/API/`. Reinstall ReaImGui through ReaPack. |
| Nothing happens, no message, no window | The binding resolved but a call inside the frame failed. Open the ReaScript console (Actions → Show console output) and paste whatever is there into the issue. |

The version asked for is `0.9`, not the newest, deliberately: the shim exists so a script can name
an older API and still run on newer installs. `M.API_VERSION` in `src/adapter/imgui.lua` is the one
place to change it.

The API names this code uses that a slice could not confirm against a running REAPER —
`InputText`, `InputInt`, `IsAnyItemActive`, `IsItemActive` — are all in the checked list, so a name
this code got wrong reports itself **by name at load time**, before the window opens, rather than
failing mid-frame. That is the third row of the table.

## A2. Where the line between a click and a drag sits

Both gestures open the same way, with the mouse going down on a cell, so:

* **Ended on the string it started on → a click.** Vertical wander does not matter, so a click that
  slides up or down its own string is still a click.
* **Ended on a DIFFERENT string of the same fret row → a drag**, and the bar spans from the string
  it started on to the string it ended on.

The fret is taken from the cell the drag started in and never moves, so wandering into another row
mid-drag leaves the bar where it was.

The residual risk: for a click to be misread as a two-string bar, the press has to land about half
a string gap off centre AND wobble across the boundary. If that happens in normal use, the fix is a
minimum travel in pixels before a drag counts, in `grid()` in `src/adapter/imgui.lua`.

## A3. What the grid and the PNG are allowed to differ in

Both are drawn from the same primitive list, so **any difference in geometry is a real bug** —
spacing, dot positions, which fret a dot is in, the length or position of a bar. Exactly two
differences are expected:

1. The on-screen title and fret marker use the ImGui window font at its own size rather than the
   size the layout asks for, so they read smaller than in the image. (Sizing text needs a font
   object attached to the context, and how that is done changed between ReaImGui versions.)
2. The on-screen ring above an open string is a stroked circle, where the PNG punches a white disc
   out of a black one.

Text *alignment* is a third difference that may or may not appear — see A5.

## A4. Storage, and what to do if a chord does not come back

The voicing is stored on the item as one encoded token, versioned, no whitespace, no quotes,
everything else percent-escaped:

```
v1;s=6;f=-1,3,2,0,1,0;g=0,0,0,0,0,0;b=;p=;n=Cadd9
```

It goes into REAPER's documented per-item extended state,
`GetSetMediaItemInfo_String(item, "P_EXT:chorddiagram", …)`, which is saved with the project by
design. An earlier design put it on a bespoke `CHORDDIAGRAM` line inside the item state chunk;
**there is no such line in the `.RPP` any more, so do not go hunting for one.**

- If **T33** fails (a chord does not survive save/reopen), the assumption the storage rests on is
  wrong and it is a real defect — new issue, no patch in place.
- If **T34** fails (a pasted copy comes up blank), REAPER does not duplicate `P_EXT:` values with
  the item; the fallback is to read the voicing off the source item and write it to the copy
  explicitly.
- The chord's **name** is written into the item's NOTES block, because an empty item has no take to
  hold a name and the notes block has to be non-empty anyway for `IMGRESOURCEFLAGS` to take effect.
  If the Media Item Manager does not surface it (**T25**), the fallback to investigate is
  `reaper.GetSetMediaItemInfo_String(item, "P_NOTES", ...)`, or a name column that reads takes only
  — in which case raise a new issue.

## A5. Text alignment — a known asymmetry

`src/core/layout.lua` gives the title and the fret marker a box and `align = "centre"`. The two
backends do not treat that field the same way:

- `src/adapter/imgui.lua` measures the string with `CalcTextSize` and centres it in the box.
- `src/adapter/lice.lua` hands the box to `JS_LICE_DrawText` and passes no alignment flag at all,
  so the PNG gets whatever LICE does by default — which has never been observed.

So if **T27** shows a centred title on screen and a left-aligned one in the image, that is not
drift in the layout: it is `drawText` in `src/adapter/lice.lua` needing either a LICE
text-alignment flag or the same manual centring the ImGui backend does. Report which of the two you
saw, for the title and for the `7fr` marker.

## A6. Notes, not checks

Things a slice recorded that nobody can stage, plus the first suspects for two failures.

- **Does REAPER re-read a file it already failed to load?** The silent repair (T37) rewrites the
  item's state chunk after rendering, on the theory that setting the chunk again makes REAPER look
  for the resource a second time. Nobody has been able to test that. If the diagram only appears
  after a close and reopen, the fix is a different nudge — `UpdateItemInProject`, or clearing
  `RESOURCEFN` and setting it back in two writes — not a different design.
- **If the sweep errors immediately with nothing happening,** `reaper.CountMediaItems(0)` and
  `reaper.GetMediaItem(0, i)` in `adapter.item.allItems` are the first suspects: they are the only
  calls that slice added, and they are the project-wide equivalents of the selection calls already
  proven.
- **A write that half-succeeds is rolled back.** If `SetItemStateChunk` succeeds and the
  extended-state write then fails, the item would carry the new diagram and the old voicing — the
  one state the design forbids. `adapter.item.writeChord` puts the original chunk back and says so.
  There is no way to make REAPER refuse that second write on purpose, so it is verified only by a
  throwaway harness. If a user ever reports "the chord could not be attached to the item", check
  that the item is exactly as it was, rather than checking the mechanism.
- **`asUndoableEdit` wraps its work in a `pcall`** so `Undo_EndBlock` always runs. An error between
  begin and end would otherwise leave an undo block open for the rest of the session, quietly
  collecting the user's next edits under a chord's label. Nothing to test; recorded so a later
  slice does not "simplify" the `pcall` away.
- **REAPER 6.44 is the floor** in `core.version.MIN_REAPER`, inherited from ReaImGui's stated host
  requirement rather than measured. The failure to watch for is it being too HIGH — a working
  install refused with "This action needs REAPER 6.44 or newer". A tester on REAPER 7.x proves
  nothing either way, which is why T5 records the version; if anyone ever reports that refusal on a
  REAPER that runs ReaImGui fine, lower it.
- **js_ReaScriptAPI has no version floor, by choice.** It is checked function by function instead —
  `JS_LICE_CreateBitmap`, `JS_LICE_Clear`, `JS_LICE_FillRect`, `JS_LICE_FillCircle`,
  `JS_GDI_CreateFont`, `JS_LICE_CreateFont`, `JS_LICE_SetFontFromGDI`, `JS_LICE_DrawText`,
  `JS_LICE_WritePNG` — because a version number would have been invented on a machine that cannot
  run REAPER, whereas the list can be read off the code. A missing one is named in the refusal.
