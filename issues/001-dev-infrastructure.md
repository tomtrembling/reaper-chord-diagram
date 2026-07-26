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

- [ ] Directory structure exists separating pure core modules from the REAPER adapter
- [ ] A placeholder core module and its spec run and pass
- [ ] The test command runs the suite headlessly, outside REAPER, and reports pass/fail
- [ ] The lint/type-check command runs and reports results
- [ ] The agent prompt's feedback-loop commands invoke the Lua tooling rather than `npm`
- [ ] Both commands succeed inside the container image used by the autonomous runner
- [ ] README prerequisites updated — Lua toolchain in, Node/npm out
- [ ] A deliberately failing spec fails the test command (proves the loop actually verifies)

## Blocked by

None — can start immediately.

## User stories addressed

- User story 41
- User story 44
