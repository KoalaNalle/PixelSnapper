-- SPDX-License-Identifier: MIT
local M = {}

function M.create(plugin, source, presets, settings, onclose)
  local preset_id, initial = settings.restore(plugin.preferences, presets)
  local preset_labels, preset_ids = {}, {}
  for _, preset in ipairs(presets.list()) do
    preset_labels[#preset_labels + 1] = preset.label
    preset_ids[preset.label] = preset.id
  end
  local dialog = Dialog { title = "Pixel Snapper", onclose = onclose }
  if not dialog then return nil end
  local updating = false

  local function refresh()
    if updating then return end
    local data = dialog.data
    local preset = presets.find(preset_id)
    local customized = settings.customized(preset_id, data, presets)
    dialog:modify { id = "preset_state", text = preset.custom and "Custom settings" or (customized and "Customized - preset defaults are unchanged" or "Preset defaults") }
    dialog:modify { id = "manual_pixel_size", enabled = data.pixel_size_mode == "Manual" }
    dialog:modify { id = "custom_palette", enabled = data.palette_mode == "Custom HEX Palette" }
    dialog:modify { id = "width", enabled = data.sizing_mode ~= "Native" }
    dialog:modify { id = "height", enabled = data.sizing_mode ~= "Native" }
    local descriptions = {
      Native = "Use the native snapped dimensions.",
      Exact = "Nearest-neighbor resize; may change aspect ratio.",
      ["Fit + Pad"] = "Preserve aspect ratio; center on transparent canvas.",
      Crop = "Center crop without scaling; pad if smaller.",
    }
    dialog:modify { id = "sizing_note", text = descriptions[data.sizing_mode] }
    dialog:modify { id = "palette_note", text = data.palette_mode == "Auto"
      and "Colors controls the engine's quantization."
      or "Colors still controls quantization before palette mapping." }
    local target = data.sizing_mode == "Native" and "Native snapped dimensions"
      or tostring(data.width) .. " x " .. tostring(data.height) .. " / " .. data.sizing_mode
    dialog:modify { id = "target_summary", text = target }
  end

  local function select_preset()
    if updating then return end
    preset_id = preset_ids[dialog.data.preset]
    local values = presets.select(preset_id, dialog.data)
    updating = true
    for _, field in ipairs(settings.fields) do
      if field.kind == "choice" then
        dialog:modify { id = field.id, option = values[field.id] }
      elseif field.kind == "boolean" then
        dialog:modify { id = field.id, selected = values[field.id] }
      else
        dialog:modify { id = field.id, text = tostring(values[field.id]) }
      end
    end
    updating = false
    refresh()
  end

  dialog:combobox { id = "preset", label = "Preset:", options = preset_labels,
    option = presets.find(preset_id).label, onchange = select_preset }
  dialog:newrow():label { id = "preset_state", text = "Preset defaults" }
  for _, field in ipairs(settings.fields) do
    if field.group then dialog:newrow():separator { text = field.group } end
    dialog:newrow()
    if field.kind == "choice" then
      dialog:combobox { id = field.id, label = field.label, options = field.options,
        option = initial[field.id], onchange = refresh }
    elseif field.kind == "boolean" then
      dialog:check { id = field.id, label = field.label, text = field.text,
        selected = initial[field.id], onclick = refresh }
    else
      -- Entries retain invalid text for validation instead of silently rounding it.
      dialog:entry { id = field.id, label = field.label,
        text = tostring(initial[field.id]), onchange = refresh }
    end
    if field.id == "custom_palette" then
      dialog:newrow():label { id = "palette_note", text = "Colors controls the engine's quantization." }
    elseif field.id == "sizing_mode" then
      dialog:newrow():label { id = "sizing_note", text = "Use the native snapped dimensions." }
    end
  end
  dialog:newrow():separator { text = "SUMMARY" }
  dialog:newrow():label { label = "Input:", text = source.width .. " x " .. source.height .. " / active frame" }
  dialog:newrow():label { id = "target_summary", label = "Output Target:", text = "Native snapped dimensions" }
  dialog:newrow():label { text = "Development build: settings only. Processing follows next." }
  dialog:newrow():button { id = "save_settings", text = "Save Settings", focus = true, onclick = function()
    local values, problem = settings.validate(dialog.data, source, presets)
    if not values then
      app.alert { title = "Pixel Snapper", text = problem }
      return
    end
    settings.save(plugin.preferences, preset_id, values)
    dialog:close()
  end }
  dialog:button { id = "cancel", text = "Cancel", onclick = function() dialog:close() end }
  refresh()
  return dialog
end

return M
