# 001 — Dev infrastructure

## Type

HITL — requires local toolchain installation and changes to the container image used for
autonomous runs.

## Parent PRD

`issues/prd.md`

## What to build

Project scaffolding so that every later slice has a working red-green loop and the agent's feedback
commands verify something real.

Create the module structure described under *Architecture* in the parent PRD: pure Lua core modules
with no REAPER API calls, and a thin adapter layer that does. Set up a Lua test runner, linting, and
type checking via annotations. Replace the starter template's Node-based feedback-loop commands in
the agent prompt with the Lua equivalents, and make sure that same tooling exists inside the
container image the autonomous runner uses — otherwise unattended iterations fail at the
feedback-loop step while interactive runs appear to work.

## Acceptance criteria

- [x] Directory structure exists separating pure core modules from the REAPER adapter
- [x] A placeholder core module and its spec run and pass
- [x] The test command runs the suite headlessly, outside REAPER, and reports pass/fail
- [x] The lint/type-check command runs and reports results
- [x] The agent prompt's feedback-loop commands invoke the Lua tooling rather than `npm`
- [x] ~~Both commands succeed inside the container image used by the autonomous runner~~ —
      **dropped**, see notes
- [x] README prerequisites updated — Lua toolchain in, Node/npm out
- [x] A deliberately failing spec fails the test command (proves the loop actually verifies)
- [x] A REAPER call placed in `src/core` fails the lint (proves the purity boundary is enforced)

## Notes

**Container criterion dropped.** Docker is not usable on the dev machine — `/usr/local/bin/docker`
is a dangling symlink with no daemon, the residue of an uninstalled Docker Desktop. Rather than
reinstate it, unattended runs will use an orchestrator driving subagents that each run
`ralph/once.sh`, an approach already proven on a previous project. `ralph/afk.sh` is therefore
unused as written; it can be removed or rewritten when that orchestration is set up.

**Lua 5.4, not 5.5.** Homebrew's default `lua` is now 5.5.0, but REAPER embeds 5.4. The toolchain is
pinned to 5.4 so specs verify against the interpreter the plugin actually runs in. Rocks install
into a project-local `.luarocks` tree rather than globally.

**The lint does architectural work.** `.luacheckrc` declares the `reaper` and `gfx` globals for
`src/adapter` only, so a REAPER call in `src/core` is reported as an undefined variable and fails
the lint. This turns "the core stays pure and headlessly testable" from a convention into something
the feedback loop enforces mechanically.

**First core module is real, not a placeholder.** `core.version` provides `CURRENT` (needed for
ReaPack metadata in slice 002) and `atLeast` for host and extension version checks (slice 009).
It compares version components as integers, so `6.10` is correctly treated as later than `6.9` —
the bug a decimal comparison would have shipped.

## Blocked by

None — can start immediately.

## User stories addressed

- User story 41
- User story 44
