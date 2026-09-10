-- Test-asset preparation and integration exercise, not extension output code.
-- Run from the repository root with Aseprite --batch --script.
local root = app.fs.currentPath
local path = app.fs.joinPath
local directory = path(root,"test_img")
local output = path(directory,"output")
app.fs.makeAllDirectories(output)
local extension = path(root,"aseprite-extension")
local function module(name) return dofile(path(extension,"lib",name..".lua")) end
local processing = module("processing")
local dependencies = {presets=module("presets"),settings=module("settings"),palette=module("palette"),runner=module("runner")}
local source = Sprite{fromFile=path(directory,"input","swamp-hex-30deg-640.png")}
assert(source.width==640 and source.height==640 and source.colorMode==ColorMode.RGB)
local source_bytes=source.cels[1].image.bytes
local source_undo=source.undoHistory.undoSteps
local source_modified=source.isModified
local pc=app.pixelColor

local function save(image,name)
  assert(image:saveAs(path(output,name)),"Could not save "..name)
  local transparent,opaque=0,0
  for pixel in image:pixels() do
    local alpha=pc.rgbaA(pixel())
    assert(alpha==0 or alpha==255,"Unexpected smoothing or partial alpha")
    if alpha==0 then transparent=transparent+1 else opaque=opaque+1 end
  end
  assert(transparent>0 and opaque>0,"Expected transparent exterior and visible terrain")
  print(string.format("SAVED: %s | %dx%d | alpha 0/255 | %d visible pixels",name,image.width,image.height,opaque))
end

local direct=Image(source.cels[1].image)
direct:resize(64,64) -- Verified Aseprite default: nearest-neighbor.
save(direct,"swamp-hex-30deg-64.png")

-- This fixture helper makes review images separately from the extension's
-- still-pending output settings. It preserves the native result's aspect ratio.
local function fit64(image)
  local copy=Image(image)
  local scale=math.min(64/image.width,64/image.height)
  local width=math.max(1,math.floor(image.width*scale+0.5))
  local height=math.max(1,math.floor(image.height*scale+0.5))
  copy:resize(width,height)
  local canvas=Image(64,64,ColorMode.RGB)
  canvas:clear()
  canvas:drawImage(copy,Point(math.floor((64-width)/2),math.floor((64-height)/2)))
  return canvas
end

for _,mode in ipairs({"auto","manual10"}) do
  local values=dependencies.presets.defaults("generic")
  if mode=="manual10" then
    values.pixel_size_mode="Manual"
    values.manual_pixel_size=10
    values.color_count=32
  end
  local result,problem,warning=processing.run({path=extension},source,1,values,dependencies)
  assert(result,problem)
  assert(not warning,warning)
  assert(not result.hasAssociatedFile and result.isModified)
  assert(source.cels[1].image.bytes==source_bytes and source.undoHistory.undoSteps==source_undo and source.isModified==source_modified)
  local image=result.cels[1].image
  save(image,"swamp-snapped-"..mode.."-native.png")
  save(fit64(image),"swamp-snapped-"..mode.."-64.png")
  result:close()
end
source:close()
print("SWAMP_ASEPRITE_TEST_OK: source unchanged; Native results unsaved; temporary files cleaned")
