# Starter Brief — REAPER Chord Diagram Plugin (working title: `chordPlugin`)

> Status: **post-grill, v3. Ready for `/write-a-prd`.**
> §1 is the decision record — settled, don't re-litigate. §8 lists what's genuinely still open.
> ⚠️ marks a technical claim not yet verified against a running REAPER install.

---

## 1. Decision record

| # | Decision | Source |
|---|---|---|
| **D1** | **Anchor = a REAPER empty item**, created manually by the user on a track. Chords live in time; many per track. | given |
| **D2** | **UI = ReaImGui.** | given |
| **D3** | **Dependencies accepted:** ReaPack + ReaImGui + js_ReaScriptAPI. Already installed on both machines. Script checks for them at startup and fails with a clear message naming what's missing. | given + Q9 |
| **D4** | **No automatic chord identification/naming.** Free-text name field. | given |
| **D5** | **No platform-specific code.** Developed on macOS, used and tested on Windows. | given |
| **D6** | **Fret span = 5.** | given |
| **D7** | **6-string standard tuning only in v1**, string count parameterised in the data model. | given |
| **D8** | **Personal / small-audience tool**, built ReaPack-ready from the start. | given |
| **D9** | **Render path = a real PNG attached to the empty item** via `RESOURCEFN` + `IMGRESOURCEFLAGS` in the item state chunk. Images scale with the item automatically. This is the user's existing manual workflow, automated. | given |
| **D10** | **Input = fretboard grid + text fast path**, synced bidirectionally. Typing `x32010` redraws the grid; clicking the grid rewrites the text. | Q1 |
| **D11** | **One shared pure-Lua layout model, two thin backends.** `layout(voicing) → primitives` in normalised coordinates; an ImGui backend draws to screen, a LICE backend draws to PNG. Hit-testing reuses the same coordinates. | Q2 |
| **D12** | **Barres are explicit — drawn by dragging across strings.** No inference. Not expressible in the text field. **Editing the text field preserves existing barres** (see §5). | Q3, Q4 |
| **D13** | **No finger numbers in v1.** Field retained in the data model so it's additive later. | Q5 |
| **D14** | **One-shot window.** Select item → hotkey → edit → Apply → closes. No selection watching, no background state. | Q6 |
| **D15** | **Name is baked into the PNG as a title *and* written to the item's name field** for searchability in the Item Manager. | Q7 |
| **D16** | **Lua tooling called directly.** `ralph/prompt.md:41-42` is edited to run Lua tools instead of `npm`. | Q8 |
| **D17** | **ReaPack repository on GitHub from day one** — public, with an auto-generated `index.xml`. The tester syncs to get every build. | Q9 |
| **D18** | **Base fret auto-derived, with a manual `+/-` override.** Nut shown in open position; `8fr`-style marker otherwise. | Q10 |
| **D19** | **Missing PNG regenerates silently** when the editor is opened on that item, plus a project-wide "Regenerate diagrams" action. | Q11 |
| **D20** | **Tracer bullet = hardcoded chord → PNG → attached to selected empty item, delivered via ReaPack and verified on Windows.** No UI. | Q12 |

---

## 2. The problem

Guitar voicings are **instrument-idiosyncratic**: a chord symbol like `Cmaj7` gives you the notes,
but not *which* shape, in *which* position, with *which* strings muted. Two guitarists playing "the
same chord" can be playing entirely different physical shapes, and the same guitarist can't reliably
reconstruct their own choice months later. A chord diagram captures what notation and chord symbols
throw away: **where your fingers actually go**.

This is mostly ordinary, nameable voicings — `G`, `Cadd9`, a barred `F#m` at the 9th — with the
occasional unusual shape. The point is **positional recall**, not exotica.

Capturing that today means: leave REAPER → open [chordpic](https://chordpic.com) → re-enter the
voicing → download a PNG → find it in Downloads → load it onto an empty item. Six context switches
per chord, tedious enough that the documentation doesn't get written — which defeats the purpose.

**Value proposition:** collapse it to *select item → hotkey → type `x32010` → Enter*, with the
diagram living in the project so it travels with it.

## 3. Who it's for

- **Developer: macOS.** Can only smoke-test on a Mac.
- **Primary user / tester: Windows.** Receives builds via ReaPack during development and is the real
  validator. **All acceptance testing happens on Windows.** They already do this workflow manually,
  so the target behaviour is known rather than guessed.

The developer cannot dogfood. That makes the delivery loop (D17) part of the critical path, not
polish — see §9.

## 4. User flow

1. User creates an **empty item** on a track where the chord occurs, and selects it.
2. Hotkey launches the plugin. **Exactly one empty item must be selected** — otherwise fail fast with
   a clear message.
3. If the item already holds a chord, the grid opens **pre-filled** from its stored data.
4. User enters the voicing: type `x32010` in the text field, and/or click grid cells. Drag across
   strings for a barre. Adjust base fret if the auto-framing isn't wanted. Type a name.
5. Apply → renders the PNG, writes it to `<project>/chord-diagrams/`, attaches it to the item, sets
   the item name, stores the voicing data, closes the window.

## 5. Architecture

The central decision (D11) is that **one pure-Lua function defines what a chord diagram looks
like**, and two thin backends draw it. Layout maths — where every bug will live — is testable
without REAPER running.

```
src/
  chord_diagram.lua      -- action entry point
  core/                  -- pure Lua. No reaper.* calls. Fully unit-tested.
    voicing.lua          -- the data model + validation
    parser.lua           -- text <-> voicing  ("x32010", "10-12-12-11-10-10")
    fretting.lua         -- base-fret derivation rules
    layout.lua           -- voicing -> drawing primitives (normalised coords)
    naming.lua           -- deterministic filename hashing
  adapter/               -- thin REAPER layer. Smoke-tested by hand.
    deps.lua             -- startup dependency checks
    item.lua             -- state chunk read/write, P_EXT storage
    render_lice.lua      -- primitives -> bitmap -> PNG
    ui_imgui.lua         -- primitives -> screen, plus hit-testing
spec/                    -- busted specs for core/ only
```

**Rules that fall out of the decisions and belong in the PRD as acceptance criteria:**

- **Text edits preserve barres.** The text field can't express a barre (D12), so re-parsing must
  merge into the existing voicing rather than replace it. Otherwise reopening a barre chord and
  nudging one string silently destroys the bar — a data-loss bug hiding in an innocent sync.
- **Multi-digit frets need separators.** `x32010` is unambiguous only below fret 10; above it the
  form is `10-12-12-11-10-10`. 🔶 Proposal: accept both, emit the separated form when any fret ≥ 10.
- **All item writes are wrapped in `Undo_BeginBlock`/`Undo_EndBlock`** so Ctrl+Z reverts a chord
  cleanly.

## 6. Item attachment mechanics

| Field | Meaning |
|---|---|
| `RESOURCEFN` | Image filename. Stored as a **relative path** when the file is in a project subfolder — which is why `<project>/chord-diagrams/` is the correct location: it survives the Mac↔Windows hop. |
| `IMGRESOURCEFLAGS` | Display bitfield. `0` none · `&1` center/tile · `&3` stretch image/text · `&5` full-height image · `&8` word wrap. |

Read/modify/write via `GetItemStateChunk` / `SetItemStateChunk` ⚠️. Known sharp edges:

- `IMGRESOURCEFLAGS` is documented as absent when notes are empty, so a notes block may need
  establishing before an image will attach.
- Chunk editing must handle "no notes yet" and "already has a chord" without corrupting unrelated
  chunk data. Contain it in one module with fixture-based tests.
- **REAPER likely caches images by filename**, so overwriting `chord.png` after an edit may not
  refresh the display. **Hash-based filenames (D-naming) sidestep this** — an edited voicing writes
  a new file, so there's nothing to bust. This is the second independent argument for hashing.

## 7. Data model

```
Voicing {
  strings:    6            # parameterised; 6 only in v1 (D7)
  tuning:     "EADGBE"     # stored, not user-editable in v1
  baseFret:   int          # auto-derived, user-overridable (D18)
  fretSpan:   5            # (D6)
  positions:  [ per string: OPEN | MUTED | fret:int (+ finger, unused in v1) ]
  barres:     [ { fret, fromString, toString } ]   # explicit only (D12)
  name:       string       # free text (D4)
}
```

Stored on the item as `P_EXT:` ⚠️ — survives copy/move of the item, invisible to the user, and is
what makes both round-trip editing (§4.3) and regeneration (D19) possible. **The PNG is a
derivative; the item data is the source of truth.**

## 8. Still open

| | Item | Resolution path |
|---|---|---|
| **O1** | ⚠️ Is `JS_LICE_WritePNG` good enough for the shapes and text needed? **The last unknown in the core chain.** | Answered by the tracer bullet (D20) |
| **O2** | ⚠️ `IMGRESOURCEFLAGS`: `&5` (full-height) vs `&3` (stretch). Stretch will distort a portrait diagram in a wide item. | Visual check during D20; `&5` expected |
| **O3** | Visual style — dot size, fret-number placement, colours, dark mode. | One opinionated default, chordpic-like. A style pass after the UI works; no settings UI in v1 |
| **O4** | `ralph/afk.sh:28` runs Claude in `docker sandbox`. The Lua toolchain must exist **inside that image**, or AFK iterations fail at the feedback loop while HITL works fine. | Infrastructure issue |
| **O5** | Not a git repo yet, and Ralph commits (`prompt.md:46`). Needs `git init` + public GitHub remote for D17. | Infrastructure issue |
| **O6** | Window position/size memory between invocations. | Trivial; defer |

## 9. Cross-platform constraints (macOS dev → Windows user)

- **Paths.** Never hand-build separators. Use `GetProjectPath()`; keep image references relative
  (§6). An absolute `/Users/...` path in a project file is dead on the tester's machine.
- **Fonts.** Any font named for LICE text or ImGui must exist on both platforms. Arial is the safe
  common denominator; macOS-only faces fail silently on Windows.
- **Filenames.** Keep hashes lowercase and separator-free so they resolve identically on both.
- **Version skew.** Pin/check REAPER, ReaImGui and js_ReaScriptAPI versions at startup, or bug
  reports become unreproducible.
- **Everything the developer verifies is macOS evidence only.** Nothing is done until confirmed on
  Windows.
- **Diagnostics.** Build a "copy diagnostic info" action early — versions, paths, last error — and
  ask for it with every bug report.

## 10. Build sequence

Ordered to match Ralph's priorities (`ralph/prompt.md:13-27`): infrastructure → tracer bullet →
expand.

1. **Infrastructure** — `git init` + public remote; repo layout (§5); busted + luacheck +
   lua-language-server; edit `ralph/prompt.md:41-42`; Lua toolchain in the Docker image (O4).
2. **Tracer bullet (D20)** — hardcoded chord → PNG → attached to the selected empty item. Ship via
   ReaPack, confirm on Windows. **Resolves O1 and O2.**
3. Voicing model + text parser, with specs.
4. Layout module + specs.
5. LICE backend driven by the layout module — replaces the hardcoded render.
6. ImGui UI: grid, click-to-toggle, base fret control, name field.
7. Text field wired to the grid, both directions (with the barre-preservation rule).
8. Barre drag interaction.
9. Round-trip: open the editor on an existing chord and load it from `P_EXT`.
10. Regeneration on open + "Regenerate diagrams in project" action (D19).
11. Visual style pass (O3).

## 11. Success criteria for v1

- Select an empty item, one hotkey, and within ~10 seconds the voicing is captured and rendered in
  the arrange view.
- Reopening the project a month later shows the diagrams, and re-launching on an existing item
  reopens the **editable** voicing, not a blank grid.
- Deleting `chord-diagrams/` and running the regenerate action restores every diagram.
- Zero browser involvement.
- The Windows user installs it via ReaPack and uses it without the developer present.

## 12. Risks

1. **O1 fails** — if LICE can't produce a decent PNG, the fallback is an external renderer, which
   drags cross-platform install friction into a project that currently has none. Slice 2 exists to
   find this out on day one.
2. **State chunk editing is string surgery**; a corrupted chunk breaks the item. One module,
   fixture-tested.
3. **Windows-only bugs the developer can't reproduce.** Mitigated by early ReaPack delivery and a
   diagnostics action, not eliminated.
4. **Scope creep** into chord identification, tab editing, MIDI generation or a voicing library.
   v1 captures a shape and pins it to a point in the timeline.

---

### Sources
- [REAPER ReaScript SDK](https://www.reaper.fm/sdk/reascript/reascript.php) · [reaper.fm](https://www.reaper.fm)
- [reaper-dev-mcp](https://github.com/Conceptual-Machines/reaper-dev-mcp) — dev-time API doc lookup; wire in from day one
- [js_ReaScriptAPI](https://github.com/juliansader/js_ReaScriptAPI) · [X-Raym ReaScript docs](https://www.extremraym.com/cloud/reascript-doc/)
- [ReaTeam State Chunk Definitions](https://github.com/ReaTeam/Doc/blob/master/State%20Chunk%20Definitions)
- [chordpic.com](https://chordpic.com) — the visual language to match
