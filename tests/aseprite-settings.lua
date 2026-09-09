-- Run from the repository root with Aseprite --batch --script.
local root = app.params["source-root"] or app.fs.currentPath
local extension = app.fs.joinPath(root, "aseprite-extension")
local presets = dofile(app.fs.joinPath(extension, "lib", "presets.lua"))
local settings = dofile(app.fs.joinPath(extension, "lib", "settings.lua"))
local source = { width = 128, height = 96 }
local count = 0

local function test(name, run)
  run()
  count = count + 1
  print("PASS: " .. name)
end

local function valid(values)
  local clean, problem = settings.validate(values, source, presets)
  assert(clean, problem)
  return clean
end

local function invalid(values, expected)
  local clean, problem = settings.validate(values, source, presets)
  assert(clean == nil and problem:find(expected, 1, true), tostring(problem))
end

test("built-in defaults stay isolated from edits", function()
  local generic = presets.defaults("generic")
  assert(generic.color_count == 16 and generic.sizing_mode == "Native" and not generic.hex_mask)
  local terrain = presets.defaults("scaleweave-terrain-64")
  assert(terrain.color_count == 32 and terrain.width == 64 and terrain.height == 64)
  assert(terrain.hex_mask and terrain.preserve_alpha and terrain.sizing_mode == "Fit + Pad")
  terrain.width = 96
  assert(presets.defaults("scaleweave-terrain-64").width == 64)
  local labels = presets.list()
  labels[1].label = "Changed"
  assert(presets.find("generic").label == "Generic / Detected Grid")
  local feature = presets.defaults("scaleweave-feature-64")
  assert(not feature.hex_mask and feature.preserve_alpha and feature.color_count == 32)
end)

test("Custom retains values; returning to a built-in restores defaults", function()
  local values = presets.defaults("scaleweave-terrain-64")
  values.width, values.height = 96, 80
  local custom = presets.select("custom", values)
  assert(custom.width == 96 and custom.height == 80 and custom.hex_mask)
  custom.color_count = 64
  assert(values.color_count == 32)
  assert(presets.select("generic", custom).sizing_mode == "Native")
  assert(presets.select("scaleweave-terrain-64", custom).width == 64)
end)

test("customization compares numeric entries without modifying defaults", function()
  local values = presets.defaults("generic")
  values.color_count = "16"
  assert(not settings.customized("generic", values, presets))
  values.color_count = "24"
  assert(settings.customized("generic", values, presets))
  assert(presets.defaults("generic").color_count == 16)
end)

test("saved settings restore across module reloads and preserve false", function()
  local values = presets.defaults("scaleweave-terrain-64")
  values.width, values.hex_mask, values.preserve_alpha = 96, false, false
  values.palette_mode, values.custom_palette = "Custom HEX Palette", "AABBCC, 112233"
  local clean = valid(values)
  assert(clean.palette_hex == "aabbcc,112233")
  local preferences = {}
  settings.save(preferences, "scaleweave-terrain-64", clean)
  clean.width = 12
  assert(preferences.last_settings.palette_hex == nil)
  local reloaded = dofile(app.fs.joinPath(extension, "lib", "settings.lua"))
  local id, restored = reloaded.restore(preferences, presets)
  assert(id == "scaleweave-terrain-64" and restored.width == 96)
  assert(restored.hex_mask == false and restored.preserve_alpha == false)
  assert(restored.custom_palette == "AABBCC, 112233")
  assert(presets.defaults(id).hex_mask and presets.defaults(id).width == 64)
end)

test("invalid stored fields fall back independently", function()
  local id, values = settings.restore({ settings_version = 1, last_preset = "missing",
    last_settings = { color_count = 0, sizing_mode = "invented", width = 96,
      height = false, hex_mask = "false", manual_pixel_size = 1.5 } }, presets)
  assert(id == "generic" and values.color_count == 16 and values.width == 96)
  assert(values.height == 64 and values.hex_mask == false and values.manual_pixel_size == 8,
    "Restored height/hex/manual: " .. tostring(values.height) .. "/" .. tostring(values.hex_mask) .. "/" .. tostring(values.manual_pixel_size))
  assert(values.sizing_mode == "Native")
end)

test("manual pixel-size boundaries and malformed values", function()
  local values = presets.defaults("generic")
  values.pixel_size_mode = "Manual"
  for _, size in ipairs({ "1", "48" }) do
    values.manual_pixel_size = size
    valid(values)
  end
  values.manual_pixel_size = "49"
  invalid(values, "between 1 and 48")
  for _, size in ipairs({ "0", "-1", "1.5", "1e2", "8 & start", "" }) do
    values.manual_pixel_size = size
    invalid(values, "positive whole number")
  end
  values.pixel_size_mode = "Auto"
  assert(valid(values).manual_pixel_size == 8)
end)

test("color count is not incorrectly capped at palette length or 256", function()
  local values = presets.defaults("generic")
  values.color_count = "257"
  values.palette_mode, values.custom_palette = "Custom HEX Palette", "112233,445566"
  assert(valid(values).color_count == 257)
  values.color_count = "16.5"
  invalid(values, "positive whole number")
end)

test("HEX validation normalizes valid RGB and rejects unchecked text", function()
  local normalized, problem, length = settings.parse_palette(" AAbbCC,112233,aabbcc ")
  assert(normalized == "aabbcc,112233" and not problem and length == 2)
  for _, text in ipairs({ "", "   ", "#112233", "11223344", "abc", "112233,",
    ",112233", "112233,,445566", "112233 & calc", "$(whoami)", "112233;445566" }) do
    assert(settings.parse_palette(text) == nil, "Accepted invalid palette: " .. text)
  end
end)

test("palette maximum counts distinct colors", function()
  local colors = {}
  for i = 1, 256 do colors[i] = string.format("%06x", i) end
  assert(settings.parse_palette(table.concat(colors, ",")))
  colors[257] = colors[1]
  assert(settings.parse_palette(table.concat(colors, ",")))
  colors[257] = "ffffff"
  assert(settings.parse_palette(table.concat(colors, ",")) == nil)
end)

test("output validation applies only to non-Native sizing", function()
  local values = presets.defaults("generic")
  values.width, values.height = "", "-1"
  assert(valid(values).width == 64)
  values.sizing_mode = "Fit + Pad"
  invalid(values, "Width")
  values.width, values.height = "96", "80"
  assert(valid(values).width == 96 and valid(values).height == 80)
  values.width = "10001"
  invalid(values, "Width")
end)

test("input bounds are checked before processing", function()
  local values = presets.defaults("generic")
  assert(settings.validate(values, nil, presets) == nil)
  assert(settings.validate(values, {width=2, height=64}, presets) == nil)
  assert(settings.validate(values, {width=10001, height=64}, presets) == nil)
end)

test("all extension Lua files parse in Aseprite", function()
  for _, filename in ipairs({ "pixel-snapper.lua", "lib/presets.lua", "lib/settings.lua", "lib/dialog.lua" }) do
    assert(loadfile(app.fs.joinPath(extension, filename)))
  end
end)

print("PIXEL_SNAPPER_SETTINGS_OK: " .. count .. " checks passed")
