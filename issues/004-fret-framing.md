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

- [ ] Separated chord strings such as `10-12-12-11-10-10` parse correctly
- [ ] The formatter emits the separated form whenever any fret is at or above the tenth
- [ ] Both forms round-trip through parse and format without loss
- [ ] Voicings containing an open string show the nut
- [ ] Voicings sitting entirely within the low frets show the nut
- [ ] Higher voicings show a window starting at the lowest fretted fret, with a position marker
- [ ] The rendered position marker states the correct fret number
- [ ] Fret span remains fixed at five in all cases
- [ ] Specs cover named chords whose framing is unambiguous: open chords, low barre shapes, and
      high-position voicings

## Blocked by

- Blocked by `issues/003-typed-chord-to-diagram.md`

## User stories addressed

- User story 3
- User story 10
