--- The delivery arrangement, checked on the dev machine.
---
--- `make index` is the real test of packaging, but it reads COMMITTED state and
--- needs Ruby, so it cannot run in `make verify` and it cannot see the change
--- you are about to make. Worse, its failure mode is silent: `reapack-index`
--- reports a provides conflict, or a provided file that does not exist, as a
--- WARNING, drops the whole package from the index, and exits 0. The tester
--- then synchronises and gets nothing.
---
--- So the three rules the arrangement rests on are asserted here instead, where
--- breaking one fails `make test` in the same edit that broke it.
---
--- The arrangement: ONE ReaPack package. `chord_diagram.lua` is its main file;
--- the other actions and the whole of `src/` come with it via `@provides`. One
--- package means one copy of the modules and no way for two packages to claim
--- the same file, which `reapack-index` treats as a conflict.

--- The directory ReaPack installs actions from.
local ACTIONS = "Chord Diagram"

--- The package's main file — the only one that is a package in its own right.
local MAIN = "chord_diagram.lua"

--- @param path string
--- @return string
local function read(path)
  local file = assert(io.open(path, "r"), "cannot read " .. path)
  local text = file:read("a")
  file:close()
  return text
end

--- Names of the files in a directory, unsorted.
--- @param dir string
--- @return string[]
local function ls(dir)
  local names = {}
  local pipe = assert(io.popen('ls "' .. dir .. '"'), "cannot list " .. dir)
  for name in pipe:lines() do
    names[#names + 1] = name
  end
  pipe:close()
  return names
end

--- The `@provides` block of the main script, as a list of trimmed lines.
---
--- The block runs from the `@provides` tag to the next tag at column one. A
--- ReaPack multiline tag owns every INDENTED line beneath it, which is exactly
--- why `@provides` has to sit above `@about` in the header rather than below:
--- `@about`'s prose would swallow it.
--- @return string[]
local function providesLines()
  local header = read(ACTIONS .. "/" .. MAIN)
  local block = header:match("\n@provides\n(.-)\n@%w")
  assert(block, "no @provides block in " .. MAIN)

  local lines = {}
  for line in (block .. "\n"):gmatch("(.-)\n") do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  return lines
end

--- Subdirectories of `src/` that hold modules, e.g. { "core", "adapter" }.
---
--- Asked of the filesystem so that a directory a later slice adds is caught
--- here rather than by a `require` failing on the tester's machine. The globs
--- in `@provides` do NOT recurse — `../src/core/*.lua` matches nothing in a
--- deeper folder — so every module directory needs its own line.
--- @return string[]
local function moduleDirs()
  local dirs = {}
  for _, name in ipairs(ls("src")) do
    if not name:match("%.lua$") then
      dirs[#dirs + 1] = name
    end
  end
  return dirs
end

describe("the ReaPack package", function()
  it("is the only package in the actions folder", function()
    for _, name in ipairs(ls(ACTIONS)) do
      if name:match("%.lua$") and name ~= MAIN then
        local text = read(ACTIONS .. "/" .. name)
        assert.is_truthy(text:match("\n@noindex\n"),
          name .. " has no @noindex, so reapack-index will index it as a "
          .. "package of its own. That conflicts with " .. MAIN
          .. " providing it, and the conflict drops the whole package.")
      end
    end
  end)

  it("provides every other action as an action", function()
    local provides = table.concat(providesLines(), "\n")

    for _, name in ipairs(ls(ACTIONS)) do
      if name:match("%.lua$") and name ~= MAIN then
        assert.is_truthy(provides:match("%[main%] " .. name:gsub("%.", "%%.")),
          name .. " is not listed as `[main] " .. name .. "` in the @provides "
          .. "of " .. MAIN .. ", so ReaPack will not install it.")
      end
    end
  end)

  it("provides every module directory as non-action files", function()
    local provides = table.concat(providesLines(), "\n")

    for _, dir in ipairs(moduleDirs()) do
      local expected = "[nomain] ../src/" .. dir .. "/*.lua > src/" .. dir .. "/"
      assert.is_truthy(provides:find(expected, 1, true),
        "src/" .. dir .. " is not shipped. Add to the @provides of " .. MAIN
        .. ":\n  " .. expected .. "\nWithout it the actions install and then "
        .. "fail on their first require.")
    end
  end)
end)
