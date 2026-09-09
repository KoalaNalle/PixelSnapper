-- SPDX-License-Identifier: MIT
-- Aseprite frontend by KoalaNalle. The snapping engine is by Hugo Duprez.
local active_dialog

function init(plugin)
  local function module(name)
    return dofile(app.fs.joinPath(plugin.path, "lib", name .. ".lua"))
  end
  local presets = module("presets")
  local settings = module("settings")
  local ui = module("dialog")

  plugin:newCommand {
    id = "PixelSnapper",
    title = "Pixel Snapper...",
    -- Verified in both upstream and installed Aseprite data/gui.xml.
    group = "sprite_size",
    onenabled = function()
      return app.isUIAvailable and app.activeSprite ~= nil and active_dialog == nil
    end,
    onclick = function()
      local source = app.activeSprite
      if not source or not app.isUIAvailable or active_dialog then return end
      active_dialog = ui.create(plugin, source, presets, settings, function() active_dialog = nil end)
      if active_dialog then active_dialog:show { wait = true, autoscrollbars = true } end
    end,
  }
end

function exit(plugin)
  if active_dialog then active_dialog:close() end
  active_dialog = nil
end
