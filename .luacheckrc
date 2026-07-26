-- Lint configuration.
--
-- The important job this file does is enforce the core/adapter boundary:
-- `reaper` and `gfx` are declared ONLY for src/adapter. A REAPER call that
-- creeps into src/core is therefore reported as an undefined global and fails
-- the lint, which is what keeps the core pure and headlessly testable.

std = "lua54"
max_line_length = 100

files["src/adapter"] = {
  read_globals = { "reaper", "gfx" },
}

files["spec"] = {
  std = "lua54+busted",
}

-- Spike scripts at the repo root are REAPER entry points, so they get the same
-- allowance as the adapter. They are throwaway by design; see issue 002.
files["Chord Diagram/chord_diagram_spike.lua"] = {
  read_globals = { "reaper" },
}
