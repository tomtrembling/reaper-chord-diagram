# 007 — Text field synced with the grid

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Bring the chord-string fast path into the UI, synced bidirectionally with the grid: typing redraws
the grid, clicking the grid rewrites the text. This is what makes a common voicing a couple of
seconds of typing rather than six mouse clicks.

Also adds the remaining controls: the name field, and the manual base-fret override alongside the
auto-derived value from slice 004.

**The important part is the merge semantics.** Re-parsing the text field must merge into the
existing voicing rather than replace it wholesale. Barres arrive in the next slice and cannot be
expressed in text at all, so a replace-on-parse implementation would silently discard them the
moment a user nudges one string. Build the merge behaviour now, while it is cheap, and spec it —
see *Interaction model* in the parent PRD.

## Acceptance criteria

- [x] A text field shows the chord string for the current voicing
- [x] Typing a valid chord string redraws the grid immediately
- [x] Clicking the grid rewrites the text field to match
- [x] Invalid or partial text does not corrupt the current voicing or throw
- [x] A name field is present and its value is used for the title and item name
- [x] The base fret shows its auto-derived value and can be overridden with a control
- [x] Overriding the base fret reframes the diagram without altering the voicing itself
- [x] Re-parsing text merges into the existing voicing rather than replacing it
- [x] Specs: merge semantics preserve voicing attributes that the text form cannot express

## What was built

The three controls sit above the grid in `src/adapter/imgui.lua`; the rules they enforce all live
in `core.voicing`, which gained `setName` and `setBaseFret` alongside the existing `setFret`.

**The sync rule, which is the part worth remembering.** The field and the voicing are two writings
of one value, and the rule is about WHEN rather than about which is master: while the user is
typing, the field is authoritative and is never normalised back at them mid-word; when the voicing
moves by any other means — a click on the grid — the voicing is authoritative and the field is
rewritten from it. Those two cases cannot both happen in one frame, so there is no loop. The
rewrite lives at the one site in `grid()` where a click changes the shape.

Every keystroke is parsed through `voicing.parse(text, nil, state.voicing)` — the three-argument
merge — and a parse that fails is discarded in silence, because half-typed input is the ordinary
state of a field somebody is typing into.

**Corrected after the first tester pass.** "Typing a valid chord string redraws the grid
immediately" was ticked on a reading of *valid* that only a COMPLETE six-position string satisfied,
so the grid did not move until the sixth character landed — which the tester reported, and which is
not the "see immediately" of user story 5. `core.voicing.parse` now reads a part-typed chord: the
positions typed set their strings and the rest come back unfingered, so the shape walks in from the
low E and back out on backspace. The merge is unchanged and still carries everything the text form
cannot say; only the frets moved to being wholly the text's business.

The UI-facing checks are in `issues/hitl-queue.md` under *Slice 007*, including the reinstatement of
the checks slice 006 invalidated. Nothing in `src/adapter/imgui.lua` has been executed: REAPER is
not installed on the dev machine, so `make verify` parses it and nothing more.

## Blocked by

- Blocked by `issues/004-fret-framing.md`
- Blocked by `issues/006-imgui-grid-window.md`

## User stories addressed

- User story 5
- User story 6
- User story 11
