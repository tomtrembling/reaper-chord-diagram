# 009 — Selection validation, dependency checks and diagnostics

## Type

AFK

## Parent PRD

`issues/prd.md`

## What to build

Make every failure state explain itself, and give the user a way to report problems usefully.

The action requires exactly one selected empty item and must fail fast and clearly otherwise, rather
than doing nothing or silently picking an item. Required extensions are checked at startup and named
individually when missing, since they are not reliably auto-installed by the package manager.

The diagnostic action matters more than usual on this project: the developer works on macOS while
the primary user is on Windows, so a Windows-only failure cannot be reproduced directly. See
*Cross-platform* in the parent PRD.

## Acceptance criteria

- [ ] Running the action with no item selected shows a clear message explaining what is needed
- [ ] Running it with more than one item selected shows a clear message and modifies nothing
- [ ] Running it on an item that is not an empty item shows a clear message and modifies nothing
- [ ] A missing required extension produces a message naming that specific extension
- [ ] Extension and host versions are checked at startup and surfaced when unsupported
- [ ] A diagnostic action copies versions, resolved paths and the last error to the clipboard
- [ ] Diagnostic output is plain text, suitable for pasting into a message
- [ ] No failure path leaves an item partially modified

## Blocked by

- Blocked by `issues/006-imgui-grid-window.md`

## User stories addressed

- User story 33
- User story 34
- User story 35
- User story 36
- User story 37
