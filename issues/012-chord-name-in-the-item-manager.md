# 012 — The chord's name in the Media Item Manager

## Type

HITL — every route needs a run in REAPER to settle, and the two most promising ones change what an
"empty item" is.

## Parent PRD

`issues/prd.md`

## The gap

PRD **user story 25**: *"As a guitarist, I want the chord's name attached to the item itself, so that
I can find it later using REAPER's Item Manager and search rather than by scrolling and squinting."*

It is not met, and the first tester pass (0.15.0, REAPER 7.78 on Windows) is what established that.

## What was found

The name reaches the item — the tester confirmed it is drawn as the diagram's title and shows on the
item in the arrange view — but **View → Media Item Manager shows no name for a chord item**. The
tester judged this normal REAPER behaviour rather than a defect, and they are right about the cause:
the manager's name column reads the active TAKE's name, and an empty item has no take to carry one.

So the story's first half works and its second half does not: the name is attached, but not in a
field the Item Manager or its search box reads.

## What was tried

`adapter.diagram.attach` writes the name into the item's `<NOTES>` block, through
`core.chunk.setImage`. That was chosen because the notes block has to be non-empty anyway — REAPER
ignores `IMGRESOURCEFLAGS` without one (slice 002) — so the name was put where a string was already
required rather than in a second place. It is what REAPER labels the empty item with in the arrange
view, which is why it looked like it would answer the Item Manager too. It does not.

## Routes worth investigating

Roughly in order of cost.

1. **A Notes column in the manager.** The manager's columns are configurable; if it can show notes,
   and if its search box reads that column, the data is already there and the answer is a line in
   the README rather than a code change. Cheapest thing to check, and it decides whether any of the
   rest is needed. Check the search box specifically — a visible column that search ignores does not
   satisfy the story.
2. **`P_NOTES` rather than the chunk.** `reaper.GetSetMediaItemInfo_String(item, "P_NOTES", …)`
   writes the same block through REAPER's own model instead of through a chunk rewrite. Unlikely to
   change what the manager reads — it is the same field — but it is one call, and it would tell us
   whether the manager is ignoring notes or ignoring *our* notes.
3. **Give the item a take.** `AddTakeToMediaItem` plus
   `GetSetMediaItemTakeInfo_String(take, "P_NAME", …)` puts the name in the field the manager
   actually reads. **This is the expensive one and it is not just an extra call:** an item with a
   take is no longer an empty item, so `adapter.item.emptySelected` (which counts
   `reaper.CountTakes(item) == 0`) would stop recognising the plugin's own items, `core.preflight`
   would refuse to reopen a chord it had just written, and it is unknown whether
   `IMGRESOURCEFLAGS` still displays the image on an item that has a take. Any attempt here has to
   answer all three, and the recognition rule would have to move from "no takes" to "carries a
   stored voicing".
4. **Accept and document.** Say in the README that chord items are found by their arrange-view
   label and not by the Item Manager, and take the story off the list deliberately rather than by
   omission. This is the right outcome if 1 and 2 fail and 3 costs the empty-item invariant.

## Acceptance criteria

- [ ] It is established, in REAPER, whether the Media Item Manager can show and SEARCH an item's
      notes
- [ ] Either the chord's name is findable in the Item Manager, or the PRD and README record that it
      is not and why
- [ ] Whatever is chosen, an item carrying a chord is still recognised by the editor and still
      displays its diagram
- [ ] The claim in `adapter.diagram.attach`'s comment matches what actually happens

## Notes

- Appendix A4 of `issues/hitl-queue.md` already anticipated this as the fallback for T25, and T25 is
  annotated with what came back.
- Small, and not urgent: nothing is lost or corrupted, and the name is on the diagram, on the item,
  and in the stored voicing. It is a findability gap.
