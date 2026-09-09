-- SPDX-License-Identifier: MIT
-- Only validated primitive settings are persisted. No shell commands here.
local M = {}

M.fields = {
  { id = "color_count", label = "Colors:", kind = "integer", group = "SNAPPING" },
  { id = "pixel_size_mode", label = "Pixel Size:", kind = "choice", options = { "Auto", "Manual" } },
  { id = "manual_pixel_size", label = "Manual Size:", kind = "integer" },
  { id = "palette_mode", label = "Palette:", kind = "choice", options = { "Auto", "Current Aseprite Palette", "Custom HEX Palette" } },
  { id = "custom_palette", label = "HEX Colors:", kind = "text" },
  { id = "sizing_mode", label = "Sizing:", kind = "choice", group = "OUTPUT", options = { "Native", "Exact", "Fit + Pad", "Crop" } },
  { id = "width", label = "Width:", kind = "integer", max = 10000 },
  { id = "height", label = "Height:", kind = "integer", max = 10000 },
  { id = "preserve_alpha", label = "Preserve Alpha:", kind = "boolean", text = "Keep transparency" },
  { id = "hex_mask", label = "Pointy Hex Mask:", kind = "boolean", text = "Transparent outside hex" },
  { id = "output_mode", label = "Output:", kind = "choice", options = { "New Sprite" } },
}

local function contains(options, value)
  for _, option in ipairs(options) do
    if option == value then return true end
  end
  return false
end

function M.integer(value)
  if type(value) == "string" then
    value = value:match("^%s*(%d+)%s*$")
    if not value then return nil end
    value = tonumber(value)
  end
  -- Aseprite's Lua build can truncate math.tointeger(1.5), so check first.
  if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge
    or value ~= math.floor(value) or value > math.maxinteger or value < math.mininteger then
    return nil
  end
  return math.tointeger(value)
end

-- This matches the CLI's RGB palette format, with stricter input syntax:
-- six hex digits per entry, optional surrounding whitespace, no '#' or alpha.
function M.parse_palette(text)
  if type(text) ~= "string" or text:match("^%s*$") then
    return nil, "Enter at least one six-digit RGB color, for example: 0d2b45,ffecd6."
  end
  local colors, seen = {}, {}
  for part in (text .. ","):gmatch("(.-),") do
    local color = part:match("^%s*(%x%x%x%x%x%x)%s*$")
    if not color then
      return nil, "Use comma-separated six-digit RGB colors only (no # or alpha)."
    end
    color = color:lower()
    if not seen[color] then
      seen[color] = true
      colors[#colors + 1] = color
      if #colors > 256 then return nil, "The palette can contain at most 256 distinct RGB colors." end
    end
  end
  return table.concat(colors, ","), nil, #colors
end

local function valid_field(field, value)
  if field.kind == "integer" then
    local number = M.integer(value)
    if number and number > 0 and (not field.max or number <= field.max) then return number end
  elseif field.kind == "choice" then
    if contains(field.options, value) then return value end
  elseif field.kind == "boolean" then
    if type(value) == "boolean" then return value end
  elseif field.kind == "text" then
    if type(value) == "string" then return value end
  end
end

function M.restore(preferences, presets)
  local id = preferences.last_preset
  if not presets.find(id) then id = "generic" end
  local values = presets.defaults(id)
  local saved = preferences.last_settings
  if preferences.settings_version == 1 and type(saved) == "table" then
    for _, field in ipairs(M.fields) do
      local value = valid_field(field, saved[field.id])
      if value ~= nil then values[field.id] = value end
    end
  end
  return id, values
end

function M.save(preferences, preset_id, values)
  local saved = {}
  for _, field in ipairs(M.fields) do saved[field.id] = values[field.id] end
  preferences.settings_version = 1
  preferences.last_preset = preset_id
  preferences.last_settings = saved
end

function M.customized(preset_id, values, presets)
  local preset = presets.find(preset_id)
  if not preset or preset.custom then return true end
  local defaults = presets.defaults(preset_id)
  for _, field in ipairs(M.fields) do
    local value = values[field.id]
    if field.kind == "integer" then value = M.integer(value) end
    if value ~= defaults[field.id] then return true end
  end
  return false
end

function M.validate(values, source, presets)
  if not source then return nil, "Open a sprite before using Pixel Snapper." end
  if source.width < 3 or source.height < 3 or source.width > 10000 or source.height > 10000 then
    return nil, "The Rust engine supports input dimensions from 3 to 10000 pixels per axis."
  end
  local clean = presets.defaults("generic")
  for _, field in ipairs(M.fields) do
    local value = valid_field(field, values[field.id])
    local inactive = (field.id == "manual_pixel_size" and values.pixel_size_mode ~= "Manual")
      or ((field.id == "width" or field.id == "height") and values.sizing_mode == "Native")
    if value ~= nil then
      clean[field.id] = value
    elseif not inactive then
      local label = field.label:gsub(":$", "")
      if field.kind == "integer" then
        return nil, label .. (field.max and " must be a whole number from 1 to 10000." or " must be a positive whole number.")
      end
      return nil, "Choose a valid value for " .. label .. "."
    end
  end
  if clean.pixel_size_mode == "Manual" then
    local maximum = math.floor(math.min(source.width, source.height) / 2)
    if clean.manual_pixel_size > maximum then
      return nil, "Manual Pixel Size must be between 1 and " .. maximum .. " for this image."
    end
  end
  if clean.palette_mode == "Custom HEX Palette" then
    local palette, problem = M.parse_palette(clean.custom_palette)
    if not palette then return nil, problem end
    -- Derived RGB argument is separate from the remembered editable text.
    clean.palette_hex = palette
  end
  return clean
end

return M
