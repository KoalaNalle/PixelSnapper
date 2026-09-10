-- SPDX-License-Identifier: MIT
local M = {}

function M.current(source, frame_number, settings)
  local selected, selected_frame
  -- This Aseprite collection throws on an out-of-range index instead of
  -- returning nil, so ipairs() cannot be used to find its end.
  for index = 1, #source.palettes do
    local palette = source.palettes[index]
    local frame = palette.frame
    local number = type(frame) == "number" and frame or frame.frameNumber
    if number <= frame_number and (not selected_frame or number >= selected_frame) then
      selected, selected_frame = palette, number
    end
  end
  if not selected then return nil, "The active frame has no usable Aseprite palette." end
  local colors = {}
  local transparent = source.colorMode == ColorMode.INDEXED and not source.backgroundLayer
    and source.transparentColor or nil
  for index = 0, #selected - 1 do
    local color = selected:getColor(index)
    if index ~= transparent and color.alpha > 0 then
      -- Partial alpha is not a CLI palette component; image alpha is independent.
      colors[#colors + 1] = string.format("%02x%02x%02x", color.red, color.green, color.blue)
    end
  end
  if #colors == 0 then return nil, "The current palette contains no non-transparent RGB colors." end
  return settings.parse_palette(table.concat(colors, ","))
end

function M.resolve(source, frame_number, values, settings)
  if values.palette_mode == "Auto" then return nil end
  if values.palette_mode == "Current Aseprite Palette" then
    return M.current(source, frame_number, settings)
  end
  return settings.parse_palette(values.custom_palette)
end

return M
