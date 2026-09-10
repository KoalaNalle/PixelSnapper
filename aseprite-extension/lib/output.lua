-- SPDX-License-Identifier: MIT
-- Aseprite output sizing only. Grid detection and quantization stay in Rust.
local M = {}

local function resized(image, width, height)
  local copy = Image(image)
  -- Aseprite's two-number overload defaults to nearest-neighbor. Work on an
  -- independent image so even a cel-backed input cannot change the source.
  copy:resize(width, height)
  return copy
end

local function centered(image, width, height)
  local x = math.floor((width - image.width) / 2)
  local y = math.floor((height - image.height) / 2)
  -- A region copy clips/pads without blending: retain exact RGBA values,
  -- including partial alpha. Out-of-bounds pixels are transparent.
  return Image(image, Rectangle(-x, -y, width, height))
end

-- values must have passed settings.validate(). This never modifies image.
function M.size(image, values)
  local mode = values.sizing_mode
  if mode == "Native" then return image end
  local width, height = values.width, values.height
  if mode == "Exact" then
    return resized(image, width, height)
  elseif mode == "Fit + Pad" then
    local scale = math.min(width / image.width, height / image.height)
    -- Round to the nearest whole pixel and keep extreme aspect ratios >= 1px.
    local fit_width = math.max(1, math.min(width, math.floor(image.width * scale + 0.5)))
    local fit_height = math.max(1, math.min(height, math.floor(image.height * scale + 0.5)))
    return centered(resized(image, fit_width, fit_height), width, height)
  elseif mode == "Crop" then
    return centered(image, width, height)
  end
  error("Choose a supported output sizing mode.", 0)
end

function M.apply(image, values, geometry)
  local result = M.size(image, values)
  if values.preserve_alpha == false then
    result = Image(result)
    local pc, hex = app.pixelColor, values.background
    local r,g,b = tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
    for pixel in result:pixels() do
      local color = pixel()
      local alpha = pc.rgbaA(color)
      local function over(channel, background)
        return math.floor((channel * alpha + background * (255-alpha) + 127) / 255)
      end
      pixel(pc.rgba(over(pc.rgbaR(color),r),over(pc.rgbaG(color),g),over(pc.rgbaB(color),b),255))
    end
  end
  -- Mask is last even when alpha preservation is off.
  if values.hex_mask then result = geometry.mask(result) end
  return result
end

return M
