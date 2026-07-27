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

-- The scripts in the ReaPack category folder are REAPER entry points: they
-- bootstrap the module path and wire the adapters together, so they get the
-- same allowance as src/adapter. No chord logic lives in them.
files["Chord Diagram"] = {
  read_globals = { "reaper" },
}
