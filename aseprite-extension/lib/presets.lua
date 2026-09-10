-- SPDX-License-Identifier: MIT
-- Presets configure the frontend; every preset uses the same Rust engine.
local M = {}

local base = {
  color_count = 16,
  pixel_size_mode = "Auto",
  manual_pixel_size = 8,
  palette_mode = "Auto",
  custom_palette = "",
  sizing_mode = "Native",
  width = 64,
  height = 64,
  preserve_alpha = true,
  background = "ffffff",
  hex_mask = false,
  output_mode = "New Sprite",
}

-- Add built-ins here. IDs are persistent; labels can change independently.
local builtins = {
  {
    id = "generic",
    label = "Generic / Detected Grid",
    description = "Upstream defaults; keep the native snapped dimensions.",
    values = {},
  },
  {
    id = "custom",
    label = "Custom",
    description = "Adjust any setting; selecting Custom keeps current values.",
    custom = true,
  },
}
local definitions = builtins

function M.configure(plugin_path)
  -- Reset first so switching between development and packaged profiles is safe.
  definitions = {}
  for _, preset in ipairs(builtins) do definitions[#definitions + 1] = preset end
  local path = app.fs.joinPath(plugin_path, "lib", "presets-development.lua")
  if app.fs.isFile(path) then
    for _, preset in ipairs(dofile(path)) do table.insert(definitions, #definitions, preset) end
  end
end

local function copy(values)
  local result = {}
  for key, value in pairs(values) do result[key] = value end
  return result
end

function M.list()
  local result = {}
  for _, preset in ipairs(definitions) do
    result[#result + 1] = {
      id = preset.id, label = preset.label,
      description = preset.description, custom = preset.custom == true,
    }
  end
  return result
end

function M.find(id)
  for _, preset in ipairs(M.list()) do
    if preset.id == id then return preset end
  end
end

function M.defaults(id)
  for _, preset in ipairs(definitions) do
    if preset.id == id then
      local result = copy(base)
      for key, value in pairs(preset.values or {}) do result[key] = value end
      return result
    end
  end
  return copy(base)
end

function M.select(id, current)
  local preset = M.find(id)
  if preset and preset.custom then return copy(current) end
  return M.defaults(id)
end

return M
