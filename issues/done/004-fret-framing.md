# 004 — Fret framing and high-position voicings

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Make the diagram frame itself correctly for any position on the neck, so that typing a chord
produces a properly-framed diagram with no extra input.

Two related pieces: the separated chord-string form for voicings at or above the tenth fret (where
single-character positions become ambiguous), and the base-fret derivation rules — show the nut for
open-position voicings, and start the window at the lowest fretted fret with a position marker
otherwise. See *Interaction model* in the parent PRD.

The manual override control belongs to the UI and is covered by a later slice; this slice is the
derivation rule and the parsing that feeds it.

## Acceptance criteria

- [x] Separated chord strings such as `10-12-12-11-10-10` parse correctly
- [x] The formatter emits the separated form whenever any fret is at or above the tenth
- [x] Both forms round-trip through parse and format without loss
- [x] Voicings containing an open string show the nut
- [x] Voicings sitting entirely within the low frets show the nut
- [x] Higher voicings show a window starting at the lowest fretted fret, with a position marker
- [x] The rendered position marker states the correct fret number
- [x] Fret span remains fixed at five in all cases
- [x] Specs cover named chords whose framing is unambiguous: open chords, low barre shapes, and
      high-position voicings

## Blocked by

- Blocked by `issues/003-typed-chord-to-diagram.md`

## User stories addressed

- User story 3
- User story 10

## What was decided

Recorded here because two of these settle questions later slices will ask again.

- **Separators.** Hyphen, comma and whitespace are accepted on input; the hyphen is the only one
  emitted. None can occur in the compact form, so the two notations are told apart by whether the
  text contains a separator at all. `toText` switches the whole string to the separated form as
  soon as one position reaches the tenth fret rather than mixing notations.
- **Base-fret override.** Reversing part of slice 005: an override is honoured, and carried across
  a re-parse, only while every fretted note still falls inside its five-fret window. Otherwise it
  is dropped and the framing goes back to derived. `voicing.canFrame(frets, base)` is public so the
  override control in slice 007 can ask the same question before offering a value.
- **Open strings do not force the nut.** A shape reaching past the fifth fret cannot show both the
  nut and its own notes; the window wins and the open string keeps its ring above the diagram, as
  songbooks notate it. Flagged for a visual confirmation in the HITL queue.
- **The position marker** is a `text` primitive with `role = "position"`, in the gutter left of the
  grid, level with the window's first cell, sized from the fret cell rather than from a constant of
  its own. Slice 006's ImGui backend and slice 011's style pass both key off that role.
- **The top line of the grid** is `role = "nut"` (heavy) only when the window starts at the first
  fret; higher up it is an ordinary `role = "fret"` line, so a backend keying off the role is never
  told there is a nut in view when there is not.
