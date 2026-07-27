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

Requires REAPER 6.44 or newer, plus ReaImGui 0.9 or newer and js_ReaScriptAPI, both installable
through ReaPack. The script checks all three at startup and names any that are missing or too old.

The package installs two actions: **Chord Diagram**, and **Chord Diagram: copy diagnostics**.

## Reporting a problem

Run the **Chord Diagram: copy diagnostics** action. It puts a plain-text report on the clipboard —
versions, the paths the plugin resolved, what is selected, whether the action would run right now,
and the last error it showed — and prints the same text to the ReaScript console. Paste it into the
report. Nothing is changed by running it.

This matters more than usual here: development is on macOS and testing on Windows, so a
Windows-only failure cannot be reproduced by the developer.

> The current package is a **spike**: the voicing is hardcoded and there is no UI. It exists to prove
> the rendering chain and settle display settings. See `issues/002-tracer-bullet-chord-on-item.md`.

## Prerequisites

**To use the plugin** (once released):

- [REAPER](https://www.reaper.fm/)
- [ReaPack](https://reapack.com/), plus ReaImGui and js_ReaScriptAPI

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
src/core/      pure Lua — voicing model, layout geometry, chunk transformations. Unit-tested.
src/adapter/   the only place the REAPER API is touched. Verified by hand in REAPER.
spec/          busted specs, mirroring src/core
issues/        PRD and the work breakdown
ralph/         agent workflow
```

