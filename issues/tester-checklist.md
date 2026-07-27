# Chord Diagram — tester checklist

Thanks for testing. This should take about 40 minutes. Work down in order — if something early
fails, later items won't mean much, so just stop and tell me.

**If anything fails:** run *Chord Diagram: copy diagnostics*, paste what it gives you, and tell me
the item number. That's all I need.

**Before you start:** save a project with a few empty items on a track (Insert → Empty item).
Nothing here needs a real project until item 22, and that one wants a throwaway copy.

---

## Setup

**1. Install.** In ReaPack, remove any existing *Chord Diagram* repository first
(Extensions → ReaPack → Manage repositories → select → Remove), then Import repositories with:

```
https://github.com/tomtrembling/reaper-chord-diagram/raw/main/index.xml
```

Browse packages → expect **one** package, *Chord Diagram*, version **0.15.0**. Install it. If an
old *Chord Diagram (spike)* is offered for removal, accept.

**2. Three actions.** Actions → Show action list, search `chord_diagram`. Expect **three** entries.
👉 *Tell me the exact names REAPER shows them under* — I've never seen this on a real install.

**3. Diagnostics.** Run *Chord Diagram: copy diagnostics* with nothing selected. It changes nothing.
👉 *Paste me the whole report.* Also say whether it reached your clipboard or fell back to a console
window.

⛔ If any action errors with `module ... not found`, stop — the install is broken and nothing else
will work.

---

## The window

**4. It opens.** Select one empty item, run *Chord Diagram*. Expect a window with a fretboard grid
and an Apply button you don't have to scroll to reach. ⛔ If it doesn't open, stop and tell me.

## Typing a chord

**5.** Type `x32010` one character at a time. The diagram should follow as you type. Finished:
cross above the low E, dots at frets 3, 2, 1 on the A, D and B strings, open rings above the G and
high E.

**6.** Type `x3201z`, then clear the field. Nothing should break and **no message should appear** —
half-typed text is normal.

**7.** Type `x-3-2-0-1-0` slowly. It must stay exactly as you typed it. Characters vanishing or the
cursor jumping to the end is a bug.

**8.** Type `10-12-12-11-10-10`. Expect a `10fr` marker to the left of the grid.

**9.** Type `x79987`. Expect no heavy nut line and a `7fr` marker. Set the first-fret box to 5 — the
diagram reframes but the chord stays `x79987`. Press Auto — it goes back to 7.

## Clicking

**10.** Click the third fret of the A string. The dot should land under the pointer, not one cell
out. Check the corners of the grid especially.

**11.** Click a dot again — it goes away and that string shows a cross (muted), not an open ring.
That's deliberate; tell me if it feels wrong.

**12.** Click above the nut to toggle a string open/muted. Clicking above the nut on a string that
has a dot should lift the dot and ring it open.

**13.** Click a shape in from scratch and watch the chord string write itself.

## Barres

A barre is a **drag across strings at one fret**. A **click** on a bar removes it.

**14.** Type `133211`, then drag along the first fret from the low E to the high E. Expect a solid
bar across the grid. ⚠️ The three fingers above the bar must **not** drop down to it, and the chord
string must still read `133211`. If the shape flattens, that's a serious bug.

**15.** Type `xx3211`, drag the first fret from the B string to the high E only. The bar should stop
at the B string.

**16.** Click the bar — it goes, dots stay. Drag again — it comes back.

**17.** With a barre chord on screen, edit the text field (`133211` → `133214`). **The bar must
survive.** This is the one I'd most like confirmed.

## Applying and reopening

**18.** Type a name, press Apply. The window closes and the diagram appears on the item.
The exported image should match what was on screen — same dots, same frets, same bar.

⚠️ Two differences are **expected, not bugs**: the title and fret marker are **centred in the window
but hard against the left edge in the exported image**, and the on-screen text is smaller and
lighter. 👉 *Tell me whether the left-aligned title is tolerable or annoying* — that decides whether
I spend time on it. But if the title is **cut off**, that's a real bug, so say so.

**19.** The name should show as the title on the diagram, on the item in the arrange view, and in
View → Media Item Manager. Try one with a comma: `C, second inversion`, apply, reopen — it must come
back intact.

**20.** Run the action again on an item that already has a chord. Everything should be pre-filled —
grid, chord string, name, first fret, and any barre.

**21.** Ctrl+Z should undo a chord in **one** press. Cancel and Escape should leave the item
completely untouched (but Escape while you're typing in a field should just clear the field, not
close the window).

**22.** Apply the same chord and name to two items — expect **one** image file in the project's
`chord-diagrams/` folder, shown on both. Now change one of them (chord or just the name): a new
image appears and the item updates **immediately**, no stale picture.

**23.** Save the project, close it, reopen it, run the action on a chord item. Everything must come
back. Then copy an item with a chord, paste it elsewhere, and run the action on the copy — it should
pre-fill the same.

## Refusals

**24.** Each of these should give a clear message and change nothing:
nothing selected · three items selected (should mention the *count*) · two audio items selected
(should still mention the count, not the type) · one audio item · an unsaved project.

## Recovery — on a throwaway project copy

⚠️ The regenerate action writes to items across the whole project. Please use a copy for its first
run.

**25.** Delete one image from the project's `chord-diagrams/` folder, then run *Chord Diagram* on
that item. The image should be back and showing by the time the window opens, with no message.
👉 *If it doesn't come back until you close and reopen the project, tell me* — useful either way.

**26.** Delete the whole `chord-diagrams/` folder. Run *Chord Diagram: regenerate missing diagrams*
with nothing selected. Everything should come back — and be the **right** diagram on each item, not
shuffled. It reports a count. Ctrl+Z should undo the lot in one press.

**27.** Run it again straight away — expect "no diagrams needed regenerating". Then run it on a real
project of yours with audio and MIDI in it: it should be quick, quiet, and change nothing.

---

## Two things to send back

**28. Screenshots**, six of them, so I don't have to ask twice:
`x32010` applied to an item · `x79987` with the `7fr` marker · `x-0-9-9-7-x` · `133211` with a full
barre · `xx3211` with a partial barre · a bar dragged across an empty, all-muted neck.

**29. Three item chunks** — this one's for my tests, not a check. Select an item, run this as a
ReaScript (Actions → New action → New ReaScript), and send me what appears in the console:

```lua
local ok, c = reaper.GetItemStateChunk(reaper.GetSelectedMediaItem(0,0), "", false)
reaper.ShowConsoleMsg(c)
```

Once for **an empty item**, once for **an item with a chord diagram on it**, once for **an audio
item**. My tests currently run against my best guess at REAPER's format — these replace the guess
with the real thing.
