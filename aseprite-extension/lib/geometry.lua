-- SPDX-License-Identifier: MIT
local M = {}

-- Pixel-center coverage of the normalized pointy hex:
-- (0.5,0), (1,0.25), (1,0.75), (0.5,1), (0,0.75), (0,0.25).
function M.inside_hex(x, y, width, height)
  local u, v = (x + 0.5) / width, (y + 0.5) / height
  local half_width = v < 0.25 and 2 * v or v > 0.75 and 2 * (1 - v) or 0.5
  return math.abs(u - 0.5) <= half_width
end

function M.mask(image)
  local copy = Image(image)
  for pixel in copy:pixels() do
    if not M.inside_hex(pixel.x, pixel.y, copy.width, copy.height) then pixel(0) end
  end
  return copy
end

return M
