# PRD — Chord Diagram Plugin for REAPER

## Problem Statement

Guitar voicings are instrument-idiosyncratic. A chord symbol like `Cmaj7` tells you the notes, but
not *which* shape, in *which* position on the neck, with *which* strings muted. Two guitarists
playing "the same chord" may be playing entirely different physical shapes — and the same guitarist,
months later, cannot reliably reconstruct their own choice. Notation and chord symbols throw away
exactly the thing that matters for recall: where the fingers actually go.

Today, documenting a voicing inside a REAPER project means leaving REAPER entirely: open a browser,
go to a chord-diagram website, re-enter the voicing by clicking a fretboard grid, download a PNG,
find it in the downloads folder, then load it onto an empty item in the project. That is six context
switches per chord.

The cost is not just time — it is that the documentation *doesn't get written*. A memory aid that is
tedious to create is a memory aid that doesn't exist, and the guitarist is left staring at a track
from three months ago with no idea what shape they played.

This is mostly ordinary, nameable voicings — an open `G`, a `Cadd9`, a barred `F#m` at the ninth
fret — with the occasional unusual shape. The need is **positional recall**, not exotica.

## Solution

An action inside REAPER that captures a chord voicing and pins its diagram to a point in the
timeline, without leaving the DAW.

The guitarist creates an empty item on a track where the chord occurs, selects it, and presses a
hotkey. A window opens with a fretboard grid. They either type the voicing as a chord string
(`x32010`) or click the grid directly; drag across strings to add a barre; type a name. On Apply,
the plugin renders a chord diagram, saves it into the project, and attaches it to that empty item —
where it displays in the arrange view and scales as the item is resized.

Reopening the plugin on an item that already carries a chord loads that voicing back into the grid
for editing, because the voicing is stored as structured data on the item rather than only as
pixels. That same stored data means a lost or missing image can be rebuilt at any time.

The result: *select item → hotkey → type → Enter*. No browser, no downloads folder, and the
diagrams travel with the project.

## User Stories

**Capturing a chord**

1. As a guitarist, I want to select an empty item and launch the plugin with a hotkey, so that I can capture a chord without reaching for a menu.
2. As a guitarist, I want to type a chord as a familiar string like `x32010`, so that I can enter a common voicing in a couple of seconds without touching the mouse.
3. As a guitarist, I want to enter voicings above the ninth fret using a separated form like `10-12-12-11-10-10`, so that high-position chords are unambiguous.
4. As a guitarist, I want to click a cell on the grid to place a finger and click it again to clear it, so that I can build a shape visually when I don't already know its chord string.
5. As a guitarist, I want typing in the text field to redraw the grid, so that I can see immediately whether what I typed is the shape I meant.
6. As a guitarist, I want clicking the grid to rewrite the text field, so that I learn the chord string for a shape I entered by hand.
7. As a guitarist, I want to mark strings as open or muted above the nut, so that the diagram records which strings are actually sounded.
8. As a guitarist, I want to drag across strings to add a barre, so that barre chords are drawn the way guitarists actually read them.
9. As a guitarist, I want the plugin never to guess at a barre on my behalf, so that a diagram never claims a fingering I didn't choose.
10. As a guitarist, I want the diagram to frame itself automatically — showing the nut for open-position chords and a fret marker for higher ones — so that a typed chord produces a correct diagram with no extra input.
11. As a guitarist, I want to override that framing when I disagree with it, so that a shape I think of as a seventh-position chord is drawn the way I think about it.
12. As a guitarist, I want to give the chord a free-text name, so that I can call it whatever is meaningful to me rather than what a naming algorithm decides.
13. As a guitarist, I want the on-screen grid to look like the diagram that will be produced, so that I can trust what I'm seeing before I commit.
14. As a guitarist, I want to close the window without applying, so that I can back out of a chord I started entering by mistake.
15. As a guitarist, I want the window to close automatically once I apply, so that I'm returned straight to my project.

**Seeing the result**

16. As a guitarist, I want the diagram to appear on the empty item in the arrange view, so that I can see the chord in the context of the arrangement.
17. As a guitarist, I want the image to scale when I resize the item, so that I can make an important chord large and a passing one small.
18. As a guitarist, I want the chord's name rendered as a title on the diagram, so that the picture is self-describing.
19. As a guitarist, I want the diagram to be legible when the item is dragged tall, so that it stays useful as a reference rather than a smudge.

**Recall and editing**

20. As a guitarist, I want to reopen the plugin on an existing chord and find the grid already filled in, so that I can adjust a voicing instead of re-entering it from scratch.
21. As a guitarist, I want to change one string of a barre chord without losing the barre, so that a small edit never silently destroys part of my diagram.
22. As a guitarist, I want to rename a chord without rebuilding it, so that I can correct a label months later.
23. As a guitarist, I want to undo an applied chord with Ctrl+Z, so that a mistake is reversible like any other REAPER edit.
24. As a guitarist, I want to copy an item to reuse a voicing elsewhere, so that a repeated chord doesn't have to be re-entered.
25. As a guitarist, I want the chord's name attached to the item itself, so that I can find it later using REAPER's Item Manager and search rather than by scrolling and squinting.

**Durability and portability**

26. As a guitarist, I want diagram images saved inside the project, so that the project folder is self-contained.
27. As a guitarist, I want a project created on one computer to display its diagrams on another, so that collaboration and machine changes don't break my documentation.
28. As a guitarist, I want the voicing stored as data on the item and not only as an image, so that the picture is a derivative and never the only copy.
29. As a guitarist, I want a missing image to be rebuilt automatically when I open the editor on that chord, so that a deleted or unsynced file repairs itself without my noticing.
30. As a guitarist, I want an action that regenerates every diagram in the project, so that I can recover in one step if the whole image folder goes missing.
31. As a guitarist, I want editing a voicing to produce a fresh image rather than overwriting the old one, so that REAPER never shows me a stale picture of a chord I just changed.
32. As a guitarist, I want identical voicings to share a single image file, so that a project with many repeats of the same chord doesn't accumulate duplicates.

**Errors and diagnosis**

33. As a guitarist, I want a clear message when no item is selected, so that I know what the plugin needs rather than watching nothing happen.
34. As a guitarist, I want a clear message when more than one item is selected, so that the plugin never silently picks one for me.
35. As a guitarist, I want a clear message when the selected item isn't an empty item, so that I don't accidentally alter an audio or MIDI item.
36. As a guitarist, I want to be told by name which required extension is missing, so that I can install it rather than guess why nothing works.
37. As a guitarist, I want an action that copies diagnostic information to my clipboard, so that I can report a problem usefully without being walked through it.

**Installing and updating**

38. As a guitarist, I want to install the plugin through ReaPack, so that setup is one URL rather than a folder of files placed by hand.
39. As a guitarist, I want updates to arrive through ReaPack synchronise, so that I'm always testing the version the developer thinks I'm testing.
40. As a guitarist, I want to bind the plugin to my own hotkey, so that it fits the way I already work.

**Development**

41. As the developer, I want the chord logic testable without REAPER running, so that I get a fast red-green loop instead of clicking through a DAW.
42. As the developer, I want the state chunk transformations tested against real captured chunks, so that the code most likely to corrupt a user's item is the code best covered.
43. As the developer, I want the on-screen grid and the exported image driven by one shared layout definition, so that the preview can never drift out of sync with the output.
44. As the developer, I want the agent's feedback-loop commands to run the project's real test tooling, so that autonomous iterations verify something rather than failing on a missing command.
45. As the developer, I want the first vertical slice to reach the Windows machine, so that the platform I cannot test is proven on day one rather than after the UI is built on top of unverified assumptions.
46. As the developer, I want the riskiest rendering assumption resolved before any UI exists, so that a failed assumption costs a day rather than a rewrite.

## Implementation Decisions

**Anchoring and attachment**

- A chord is anchored to a **REAPER empty item**, created manually by the user. Chords therefore
  live in time, and a track can carry many. The plugin does not create items in v1.
- The diagram is attached using REAPER's item-notes image support, via the item state chunk fields
  `RESOURCEFN` (image filename) and `IMGRESOURCEFLAGS` (display bitfield). `RESOURCEFN` is stored as
  a relative path when the image lives in a project subfolder — which is why images are written to a
  dedicated subfolder of the project, and is what makes projects portable between machines.
- The display flag is expected to be the "full height image" value rather than "stretch", which
  would distort a portrait-shaped diagram inside a wide item. To be confirmed visually in the first
  slice.
- The voicing itself is stored as structured data in the item's extended state. **The item data is
  the source of truth; the PNG is a derivative.** This enables round-trip editing and regeneration.
- The chord's name is both rendered as a title in the image and written to the item's name field, so
  it is searchable in REAPER's Item Manager.
- All item writes are wrapped in an undo block.

**Interaction model**

- Entry is a fretboard grid **plus** a text fast path, synced bidirectionally.
- Barres are **explicit only** — added by dragging across strings, never inferred. Barres are not
  expressible in the text field; consequently, re-parsing text must *merge* into the existing
  voicing rather than replace it, so that editing text preserves barres. This is a data-loss guard,
  not a convenience.
- Base fret is auto-derived — nut shown in open position, a fret marker otherwise — with a manual
  override.
- Fret span is fixed at five.
- Finger numbers are not rendered in v1; the field is retained in the data model so it is additive
  later.
- The window is **one-shot**: select item, hotkey, edit, Apply, close. No selection watching and no
  background state.
- The action requires exactly one selected empty item and fails fast with a clear message otherwise.

**Architecture**

The central decision is that **one pure-Lua layout definition drives both the on-screen grid and the
exported image**, via two thin backends. This prevents preview/output drift and makes the geometry —
where the bugs live — testable without REAPER.

Three deep core modules, pure Lua with no REAPER API calls:

- **Voicing** — small interface (`parse`, `toText`, `setFret`, `setBarre`, `baseFret`,
  `fingerprint`) hiding both text notations, the separator rule for frets at or above the tenth, the
  base-fret derivation rules, the barre-preservation merge, validation, and voicing hashing. Parsing
  lives here rather than in a separate module specifically so the barre-preservation rule is an
  internal invariant instead of leaking into the UI.
- **Layout** — `compute(voicing, width, height)` returning drawing primitives in normalised
  coordinates, plus `cellAt(x, y)` for hit-testing. Hides all geometry: grid spacing, nut versus
  fret-marker rendering, dot placement, barre bars, title placement, open/muted glyphs. Hit-testing
  reuses the same coordinates as drawing, so clicks land exactly on what is displayed.
- **Chunk** — pure string-to-string transformation of item state chunk text (`readVoicing`,
  `setImage`). Hides insertion of the image fields, the difference between "item has no notes yet"
  and "item already carries a chord", and the requirement not to corrupt unrelated chunk data.
  Extracting this from the REAPER adapter is what makes the project's second-highest risk testable.

Thin adapter modules, hand-tested: item read/write (state chunk access and undo blocks, delegating
to Chunk), the LICE rendering backend (primitives to bitmap to PNG), the ImGui backend (primitives
to screen, plus input), a startup dependency check, and a path/filename helper isolating all
platform-sensitive behaviour.

**Naming and storage**

- Image filenames are derived from a **hash of the voicing**. This gives deduplication for free,
  makes re-rendering an unchanged voicing a no-op, and — critically — sidesteps REAPER's likely
  caching of images by filename, since an edited voicing produces a new filename rather than
  overwriting one REAPER may still be showing.
- Hashed filenames are lowercase and separator-free so they resolve identically on both platforms.

**Dependencies and delivery**

- Requires ReaPack, ReaImGui and js_ReaScriptAPI. These are not reliably auto-installed across
  ReaPack repositories, so the script checks for them at startup and fails with a message naming
  what is missing.
- Distributed as a **public ReaPack repository on GitHub from day one**, with a generated index. The
  tester receives every build through ReaPack synchronise. ReaPack fetches the index over plain
  HTTPS, so the repository must be public.

**Cross-platform**

- Development is on macOS; the primary user and all acceptance testing are on Windows. Nothing is
  "done" until confirmed on Windows.
- No hand-built path separators; project-relative image references throughout.
- Any font named for image text or UI must exist on both platforms.
- Extension and REAPER versions are checked at startup so bug reports remain reproducible.

**Project infrastructure**

- The agent workflow's feedback-loop commands are changed from the template's Node commands to the
  project's actual Lua tooling: a Lua test runner, plus linting and type checking via annotations.
- The Lua toolchain must also exist inside the container image used for autonomous runs, or
  autonomous iterations fail at the feedback-loop step while interactive runs succeed.
- The project must be initialised as a git repository with a public remote, since the agent workflow
  commits and the delivery mechanism depends on it.

## Testing Decisions

**What makes a good test here.** Tests exercise observable behaviour through a module's public
interface, and describe *what* the system does rather than *how*. A test that survives an internal
refactor is a good test; one that breaks when a private function is renamed was testing
implementation. Tests are written one at a time in a red-green cycle against code that exists — not
in bulk against imagined behaviour, which produces tests that verify the shape of data structures
instead of real outcomes. Mocking is avoided: the modules chosen for testing are pure, so they need
no test doubles at all.

**Modules under test** — the three deep core modules, all pure Lua and runnable headlessly outside
REAPER:

- **Voicing** — round-tripping text to voicing and back; the separator form for high-position
  chords; base-fret derivation checked against named chords whose framing is unambiguous (open
  chords, barre shapes, high-position voicings); the barre-preservation rule when text is edited;
  fingerprint stability, so that an unchanged voicing hashes identically and any change produces a
  different hash.
- **Layout** — geometry for known voicings; nut versus fret-marker framing; barre bars spanning the
  correct strings; and hit-testing round-tripping — a coordinate produced for a given string and
  fret must map back to that same string and fret.
- **Chunk** — fixture-based, using **real item state chunks captured from REAPER** as inputs.
  Covers attaching an image to an item with no notes, replacing the image on an item that already
  carries a chord, reading a stored voicing back out, and leaving unrelated chunk content untouched.
  This targets the corruption risk directly.

**Not unit-tested:** the adapter modules. Testing them would require mocking the REAPER API
wholesale, producing exactly the implementation-coupled tests the project's TDD guidance warns
against. They are verified by hand in REAPER — and, because the developer works on macOS while the
user is on Windows, confirmed on Windows before anything is considered complete.

**Prior art.** There is none in this repository — it is an empty starter template, so these are the
first tests and they set the conventions. The nearest guidance is the project's existing TDD
material, which supplies the behaviour-not-implementation principle and the vertical-slice cadence
followed above.

## Out of Scope

- **Automatic chord identification or naming.** Names are free text. Deriving a chord symbol from a
  voicing is a hard problem and a separate feature.
- **Finger numbers** on dots. The data model retains the field; nothing renders or edits it in v1.
- **Instruments other than 6-string guitar**, and **alternate tunings**. String count and tuning are
  parameterised in the data model so support is additive, but only standard 6-string is built.
- **Left-handed or mirrored diagrams.**
- **A settings or style-customisation UI.** One opinionated default visual style.
- **A persistent window that follows selection**, and batch entry across many items.
- **Creating empty items.** The user creates them; the plugin only fills them.
- **A chord library, browser, or lookup tool.** This captures what was played; it does not suggest
  what to play.
- **MIDI generation or tab editing.**
- **Cleaning up orphaned image files** when items are deleted.

## Further Notes

**Unresolved, in priority order.** The single remaining unknown in the core chain is whether the
js_ReaScriptAPI LICE functions can produce an acceptable-quality PNG of shapes and text from Lua. If
they cannot, the fallback is an external renderer, which would drag cross-platform installation
friction into a project that currently has none. The first vertical slice exists to answer this on
day one. The same slice settles which image display flag frames a portrait diagram correctly.

**Build sequence.** Infrastructure first (repository initialisation and remote, module layout, Lua
test tooling, agent feedback-loop commands, container toolchain), then the tracer bullet: a
hardcoded voicing rendered to a PNG and attached to a selected empty item, with no UI at all,
delivered through ReaPack and confirmed on Windows. That slice touches every layer and resolves both
open technical unknowns and the platform gap simultaneously. Only then the core modules with their
tests, the rendering backend driven by the layout module, the UI, text sync, barre dragging,
round-trip loading, regeneration, and finally a visual style pass.

**Known risks.** A corrupted state chunk breaks a user's item, which is why the chunk
transformations are isolated and fixture-tested. Windows-only failures cannot be reproduced by the
developer, which is mitigated — not eliminated — by early ReaPack delivery and a diagnostics action.
Scope creep toward chord identification, a voicing library, or tab editing is the most likely way
this project loses focus; v1 captures a shape and pins it to a point in the timeline.

**Development tooling.** A REAPER API documentation MCP server is available and should be wired into
the development environment from the start, so API signatures are looked up rather than guessed —
the ReaScript API is large and the state chunk format is sparsely documented.
