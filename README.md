# Chord Diagram for REAPER

A REAPER script that captures a guitar chord voicing and pins its diagram to an empty item on the
timeline — no browser, no downloads folder.

Guitar voicings are instrument-idiosyncratic: a chord symbol tells you the notes, but not which
shape, in which position, with which strings muted. This tool documents what was actually played, so
that a track makes sense again months later.

**Status:** in development. See `starter-brief.md` for the decision record, `issues/prd.md` for the
PRD, and `issues/` for the work breakdown.

## Install

In REAPER: **Extensions → ReaPack → Import repositories**, and paste:

```
https://github.com/tomtrembling/reaper-chord-diagram/raw/main/index.xml
```

Then **Extensions → ReaPack → Browse packages**, find *Chord Diagram*, and install. Updates arrive
via **Extensions → ReaPack → Synchronise packages**.

*Chord Diagram* is a single package. Installing it installs all three actions and the modules they
are built from, and updating it updates them together — there is nothing else in the list to find.

### Dependencies

- **REAPER 6.44 or newer.** The floor comes from ReaImGui, not from anything this plugin does.
- **ReaImGui 0.9 or newer** — the fretboard window. Install through ReaPack.
- **js_ReaScriptAPI** — draws the diagram and writes the PNG. Install through ReaPack.

All three are checked when an action starts, and any that is missing or too old is named. Nothing is
modified when the check refuses.

### The three actions

Open **Actions → Show action list** and search for `chord_diagram` to find them. REAPER lists them
under their **filenames**, which is what the table below gives — confirmed on REAPER 7.78:

| Action, as the action list shows it | What it does | Needs a selection |
| --- | --- | --- |
| `chord_diagram.lua` | Opens the fretboard window on the selected item, to build or edit its chord | Exactly one empty item |
| `chord_diagram_regenerate.lua` | Rebuilds every diagram image missing from the project, in one undo step | No |
| `chord_diagram_diagnostics.lua` | Copies a report to the clipboard for a bug report; changes nothing | No |

### The flow, once it has a hotkey

`chord_diagram.lua` is the one worth binding a key to — the other two are occasional. Select it in
the action list, press **Add…** under *Shortcuts for selected action*, and press the key you want.

Then, with the project saved at least once (the image is written beside it):

1. Insert an empty item on a track and select it — **Insert → Empty item**.
2. Press the hotkey. The fretboard window opens.
3. Type the chord as a string (`x32010`, or `10-12-12-11-10-10` above the ninth fret), or click the
   grid to place fingers and drag across a fret to lay a barre. The two stay in sync.
4. Type a name. It is drawn as the diagram's title and becomes the item's name.
5. **Apply** writes the diagram to the item. **Cancel** or **Escape** leaves the item untouched.

Pressing the hotkey again on the same item reopens the chord for editing: the voicing is stored on
the item, so it comes back on the grid, and copying the item copies the chord with it.

## If a diagram disappears

The chord is stored on the item as data and the image is only ever derived from it, so a missing
picture is a file that has not been written yet rather than something that is lost.

Opening `chord_diagram.lua` on an item whose image has gone rebuilds it before the window opens, and
you should not notice. If a whole folder of them has gone — a project copied to another machine
without it, or the images tidied away as unused files — run `chord_diagram_regenerate.lua`. Nothing
needs to be selected; it rebuilds every missing diagram in the project in a single undoable step and
reports how many, including when the answer is none.

## Reporting a problem

Run the `chord_diagram_diagnostics.lua` action. It puts a plain-text report on the clipboard —
versions, the paths the plugin resolved, what is selected, whether the action would run right now,
and the last error it showed — and prints the same text to the ReaScript console. Paste it into the
report. Nothing is changed by running it.

This matters more than usual here: development is on macOS and testing on Windows, so a
Windows-only failure cannot be reproduced by the developer.

## Prerequisites

**To use the plugin:**

- [REAPER](https://www.reaper.fm/) 6.44 or newer
- [ReaPack](https://reapack.com/), plus ReaImGui 0.9 or newer and js_ReaScriptAPI

**To develop it:**

- [Lua 5.4](https://www.lua.org/) — matching the interpreter REAPER embeds
- [LuaRocks](https://luarocks.org/)
- [lua-language-server](https://github.com/LuaLS/lua-language-server)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI and a Claude Pro or Max
  subscription, if using the agent workflow

```sh
brew install lua@5.4 luarocks lua-language-server
make install-deps          # busted + luacheck into a project-local .luarocks tree
```

## Feedback loops

```sh
make test      # busted specs, headless — no REAPER required
make lint      # luacheck
make check     # lua-language-server type check
make verify    # all three
```

`make lint` enforces the architectural boundary: modules under `src/core` are pure Lua and may never
call the REAPER API, so a stray `reaper` call there fails the lint. Anything needing the API belongs
in `src/adapter`.

## Layout

```
Chord Diagram/ the three action scripts — REAPER entry points, and the ReaPack category folder
src/core/      pure Lua — voicing model, layout geometry, chunk transformations. Unit-tested.
src/adapter/   the only place the REAPER API is touched. Verified by hand in REAPER.
spec/          busted specs, mirroring src/core
ref/           the slice 002 spike and developer-only ReaScripts. `@noindex`, so never shipped.
issues/        PRD and the work breakdown
ralph/         agent workflow
index.xml      the ReaPack index, generated by `make index` — tracked, because ReaPack fetches it
```

### How it is packaged

`src/` sits at the repository root, next to the action folder rather than inside it, so the lint's
core/adapter boundary and the test path stay simple. ReaPack does not install that shape: the
`@provides` header in `chord_diagram.lua` retargets the modules into the package's own folder, so
an installed copy has `src/` directly beside the scripts. Each script puts both candidates on
`package.path`, which is why it also runs straight out of a clone.

The whole plugin is **one package**. The other two actions are `[main]` entries in that header and
carry `@noindex` so `reapack-index` does not also index them as packages of their own — two
packages claiming the same file is a conflict, and `reapack-index` resolves a conflict by dropping
a package from the index and still exiting 0. `spec/packaging_spec.lua` asserts the arrangement, and
`make index` re-checks the generated file, because that failure is otherwise silent.

```sh
make index     # regenerate index.xml from COMMITTED state, then check it
```

A packaging change needs a `@version` bump to take effect: a version already in the index is never
rewritten, so the same version number means the old entry stands and the new `@provides` is ignored.

