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
