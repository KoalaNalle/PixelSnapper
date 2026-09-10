-- SPDX-License-Identifier: MIT
-- Pixel-level output tests in Aseprite, independent of Rust grid detection.
local root = app.params["source-root"] or app.fs.currentPath
local output = dofile(app.fs.joinPath(root,"aseprite-extension","lib","output.lua"))
local geometry = dofile(app.fs.joinPath(root,"aseprite-extension","lib","geometry.lua"))
local pc, count = app.pixelColor, 0
local function test(name, run)
  local ok, problem = xpcall(run,debug.traceback)
  assert(ok,name..": "..tostring(problem))
  count=count+1
  print("PASS: "..name)
end
local function fixture(width,height)
  local image=Image(width,height,ColorMode.RGB)
  local alpha={0,1,128,254,255}
  for pixel in image:pixels() do
    local index=pixel.y*width+pixel.x
    pixel(pc.rgba(17+index%200,31+(index*3)%200,43+(index*7)%200,alpha[index%5+1]))
  end
  return image
end
local function apply(image,mode,width,height)
  local bytes,id,version=image.bytes,image.id,image.version
  local result=output.apply(image,{sizing_mode=mode,width=width,height=height})
  assert(result and result.colorMode==ColorMode.RGB)
  assert(image.bytes==bytes and image.id==id and image.version==version,"Input image changed")
  if mode~="Native" then assert(result.width==width and result.height==height) end
  return result
end
local function pixels_are_copies(result,source)
  local allowed={[0]=true} -- transparent padding, plus exact original RGBA values
  for pixel in source:pixels() do allowed[pixel()]=true end
  for pixel in result:pixels() do assert(allowed[pixel()],"Sizing introduced a new RGBA color") end
end

test("Native preserves bytes and ignores target dimensions",function()
  local source=fixture(3,2)
  local result=apply(source,"Native",nil,nil)
  assert(result.width==3 and result.height==2 and result.bytes==source.bytes)
end)

test("Exact integer enlargement repeats pixels including partial alpha",function()
  local source=fixture(3,2)
  local result=apply(source,"Exact",6,4)
  for pixel in result:pixels() do
    assert(pixel()==source:getPixel(math.floor(pixel.x/2),math.floor(pixel.y/2)))
  end
end)

test("Exact reduction samples original pixels without interpolation",function()
  local source=fixture(4,4)
  local result=apply(source,"Exact",2,2)
  for pixel in result:pixels() do assert(pixel()==source:getPixel(pixel.x*2,pixel.y*2)) end
end)

test("Exact noninteger scaling and aspect changes retain exact RGBA values",function()
  local source=fixture(3,2)
  local result=apply(source,"Exact",5,3)
  local xs,ys={0,0,1,1,2},{0,0,1}
  for pixel in result:pixels() do assert(pixel()==source:getPixel(xs[pixel.x+1],ys[pixel.y+1])) end
end)

test("Fit landscape enlarges uniformly and centers with transparent padding",function()
  local source=fixture(4,2)
  local result=apply(source,"Fit + Pad",8,7)
  for pixel in result:pixels() do
    local expected=0
    if pixel.y>=1 and pixel.y<5 then expected=source:getPixel(math.floor(pixel.x/2),math.floor((pixel.y-1)/2)) end
    assert(pixel()==expected)
  end
end)

test("Fit portrait centers horizontally with an odd padding difference",function()
  local source=fixture(2,4)
  local result=apply(source,"Fit + Pad",7,8)
  for pixel in result:pixels() do
    local expected=0
    if pixel.x>=1 and pixel.x<5 then expected=source:getPixel(math.floor((pixel.x-1)/2),math.floor(pixel.y/2)) end
    assert(pixel()==expected)
  end
end)

test("Fit reduction rounds the fitted dimension to the nearest whole pixel",function()
  local source=fixture(8,4)
  local result=apply(source,"Fit + Pad",3,3)
  local xs={0,2,5}
  for pixel in result:pixels() do
    local expected=pixel.y<2 and source:getPixel(xs[pixel.x+1],pixel.y*2) or 0
    assert(pixel()==expected)
  end
end)

test("Fit extreme aspect ratios never creates a zero-pixel dimension",function()
  for _,size in ipairs({{100,1,1,9},{1,100,9,1},{3,2,1,1}}) do
    local source=fixture(size[1],size[2])
    local result=apply(source,"Fit + Pad",size[3],size[4])
    pixels_are_copies(result,source)
    local center=result:getPixel(math.floor((size[3]-1)/2),math.floor((size[4]-1)/2))
    assert(center==source:getPixel(0,0))
  end
end)

test("Crop removes edges at original scale and resolves odd offsets consistently",function()
  local source=fixture(5,4)
  local result=apply(source,"Crop",2,3)
  for pixel in result:pixels() do assert(pixel()==source:getPixel(pixel.x+2,pixel.y+1)) end
end)

test("Crop enlarges the canvas with transparent padding without scaling",function()
  local source=fixture(2,3)
  local result=apply(source,"Crop",5,6)
  for pixel in result:pixels() do
    local expected=0
    if pixel.x>=1 and pixel.x<3 and pixel.y>=1 and pixel.y<4 then expected=source:getPixel(pixel.x-1,pixel.y-1) end
    assert(pixel()==expected)
  end
end)

test("Crop can trim one axis and pad the other",function()
  local source=fixture(5,2)
  local result=apply(source,"Crop",3,5)
  for pixel in result:pixels() do
    local expected=0
    if pixel.y>=1 and pixel.y<3 then expected=source:getPixel(pixel.x+1,pixel.y-1) end
    assert(pixel()==expected)
  end
end)

test("Same-size operations preserve every RGBA byte",function()
  local source=fixture(5,3)
  for _,mode in ipairs({"Exact","Fit + Pad","Crop"}) do
    assert(apply(source,mode,5,3).bytes==source.bytes)
  end
end)

test("Cel-backed input pixels and undo history remain unchanged",function()
  local source=Sprite(5,3,ColorMode.RGB)
  source.cels[1].image=fixture(5,3)
  local before,dirty=source.undoHistory.undoSteps,source.isModified
  for _,mode in ipairs({"Native","Exact","Fit + Pad","Crop"}) do
    pixels_are_copies(apply(source.cels[1].image,mode,8,9),source.cels[1].image)
    assert(source.undoHistory.undoSteps==before and source.isModified==dirty)
    assert(source.width==5 and source.height==3)
  end
  source:close()
end)

test("Hex mask has symmetric crisp coverage at arbitrary canvas dimensions",function()
  for _,size in ipairs({{64,64},{17,31},{8,5},{1,1},{1,9},{9,1}}) do
    local width,height=size[1],size[2]
    local source=Image(width,height,ColorMode.RGB)
    local solid=pc.rgba(21,43,65,128)
    source:clear(solid)
    local result=geometry.mask(source)
    for pixel in result:pixels() do
      assert(pixel()==0 or pixel()==solid)
      assert(pixel()==result:getPixel(width-1-pixel.x,pixel.y))
      assert(pixel()==result:getPixel(pixel.x,height-1-pixel.y))
    end
    assert(source:isPlain(solid))
  end
  assert(geometry.inside_hex(31,0,64,64) and geometry.inside_hex(32,0,64,64))
  assert(not geometry.inside_hex(30,0,64,64))
  assert(geometry.inside_hex(0,16,64,64) and geometry.inside_hex(63,47,64,64))
  assert(not geometry.inside_hex(0,15,64,64) and not geometry.inside_hex(63,48,64,64))
end)

test("Alpha removal composites against selected RGB and makes padding opaque",function()
  local source=Image(3,1,ColorMode.RGB)
  source:drawPixel(0,0,pc.rgba(200,50,0,0))
  source:drawPixel(1,0,pc.rgba(200,50,0,128))
  source:drawPixel(2,0,pc.rgba(200,50,0,255))
  local before=source.bytes
  local result=output.apply(source,{sizing_mode="Crop",width=5,height=3,preserve_alpha=false,background="6496c8"},geometry)
  local background=pc.rgba(100,150,200,255)
  assert(result:getPixel(0,0)==background and result:getPixel(1,1)==background)
  assert(result:getPixel(2,1)==pc.rgba(150,100,100,255))
  assert(result:getPixel(3,1)==pc.rgba(200,50,0,255))
  for pixel in result:pixels() do assert(pc.rgbaA(pixel())==255) end
  assert(source.bytes==before)
end)

test("Hex applies after sizing and flattening without a border",function()
  local source=Image(4,4,ColorMode.RGB)
  source:clear(pc.rgba(100,50,20,255))
  local result=output.apply(source,{sizing_mode="Exact",width=64,height=64,preserve_alpha=false,background="ffffff",hex_mask=true},geometry)
  for pixel in result:pixels() do
    local expected=geometry.inside_hex(pixel.x,pixel.y,64,64) and pc.rgba(100,50,20,255) or 0
    assert(pixel()==expected)
  end
end)

print("PIXEL_SNAPPER_OUTPUT_OK: "..count.." checks passed")
