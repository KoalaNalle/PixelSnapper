-- SPDX-License-Identifier: MIT
-- Run against an extracted SHIPPING archive, not source modules.
local root=assert(app.params["plugin-root"],"Pass plugin-root for the extracted package")
local function module(name) return dofile(app.fs.joinPath(root,"lib",name..".lua")) end
assert(app.fs.isFile(app.fs.joinPath(root,"package.json")))
assert(not app.fs.isFile(app.fs.joinPath(root,"lib","presets-development.lua")))
local presets,settings=module("presets"),module("settings")
presets.configure(root)
assert(#presets.list()==2 and presets.find("generic") and presets.find("custom"))
assert(not presets.find("scaleweave-terrain-64") and not presets.find("scaleweave-feature-64"))
local old={settings_version=1,last_preset="scaleweave-terrain-64",last_settings={sizing_mode="Fit + Pad",width=64,height=64,hex_mask=true}}
local id,restored=settings.restore(old,presets)
assert(id=="generic" and restored.hex_mask and restored.width==64)

local command
local plugin={path=root,preferences={}}
function plugin:newCommand(value) command=value end
dofile(app.fs.joinPath(root,"pixel-snapper.lua"))
init(plugin)
assert(command.id=="PixelSnapper" and command.group=="sprite_size" and not command.onenabled())
exit(plugin)

local source=Sprite(64,64,ColorMode.RGB)
local pc=app.pixelColor
for pixel in source.cels[1].image:pixels() do
  pixel(pc.rgba(pixel.x<32 and 40 or 180,pixel.y<32 and 190 or 60,70,pixel.x<8 and 0 or 255))
end
local before,undo=source.cels[1].image.bytes,source.undoHistory.undoSteps
local deps={presets=presets,settings=settings,runner=module("runner"),palette=module("palette"),output=module("output"),geometry=module("geometry")}
local values=presets.defaults("generic")
values.sizing_mode,values.width,values.height="Fit + Pad",64,64
values.hex_mask=true
local result,problem,warning=module("processing").run(plugin,source,1,values,deps)
assert(result,problem)
assert(not warning,warning)
assert(result.width==64 and result.height==64 and not result.hasAssociatedFile)
assert(pc.rgbaA(result.cels[1].image:getPixel(0,0))==0)
assert(pc.rgbaA(result.cels[1].image:getPixel(32,32))==255)
assert(source.cels[1].image.bytes==before and source.undoHistory.undoSteps==undo)
result:close(); source:close()
print("PIXEL_SNAPPER_PACKAGE_OK: shipping presets, preference migration, command registration, bundled engine and masked 64x64 output")
