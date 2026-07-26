# Chord Diagram for REAPER

A REAPER script that captures a guitar chord voicing and pins its diagram to an empty item on the
timeline — no browser, no downloads folder.

Guitar voicings are instrument-idiosyncratic: a chord symbol tells you the notes, but not which
shape, in which position, with which strings muted. This tool documents what was actually played, so
that a track makes sense again months later.

**Status:** in development. See `starter-brief.md` for the decision record, `issues/prd.md` for the
PRD, and `issues/` for the work breakdown.

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

## Workflow

This project uses the workflow from the
[AIHero Engineer Workshop 2026](https://www.aihero.dev/ai-engineer-workshop-2026~dwnll), with a
"Ralph" worker and the `grill-me`, `write-a-prd`, `prd-to-issues`, `tdd` and
`improve-codebase-architecture` skills.

Planning: brief → `/grill-me` → `/write-a-prd` → `/prd-to-issues`.
Execution: run Ralph over the issue backlog using TDD.
