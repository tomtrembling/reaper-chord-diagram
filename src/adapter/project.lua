--- Paths and the project folder. The only place that knows about separators.
---
--- Two different separators are in play and confusing them is how projects stop
--- being portable:
---
---   * The FILESYSTEM path handed to the renderer uses the platform separator.
---   * The path STORED IN THE ITEM is relative and always uses forward slashes,
---     so a project written on Windows still resolves on macOS.
local M = {}

--- The platform's path separator, taken from Lua itself rather than from an OS
--- test, so there is no hand-built branch to get wrong.
M.SEP = package.config:sub(1, 1)

--- Where diagram images live, relative to the project.
M.FOLDER = "chord-diagrams"

--- The directory holding the current project, or nil if it has never been
--- saved — in which case there is nowhere project-relative to put an image.
--- @return string|nil
function M.dir()
  local _, filename = reaper.EnumProjects(-1, "")
  if filename == nil or filename == "" then
    return nil
  end
  return filename:match("^(.*)[/\\][^/\\]*$")
end

--- The project-relative reference stored in the item chunk.
--- @param name string
--- @return string
function M.relativeImagePath(name)
  return M.FOLDER .. "/" .. name
end

--- The absolute filesystem path the renderer writes to.
--- @param dir string
--- @param name string
--- @return string
function M.absoluteImagePath(dir, name)
  return dir .. M.SEP .. M.FOLDER .. M.SEP .. name
end

--- Make sure the image folder exists inside the project.
--- @param dir string
function M.ensureImageFolder(dir)
  reaper.RecursiveCreateDirectory(dir .. M.SEP .. M.FOLDER, 0)
end

--- Is there already a file at this path?
--- @param path string
--- @return boolean
function M.exists(path)
  return reaper.file_exists(path)
end

return M
