-- Integration checks in Aseprite's Lua runtime, using the real Rust executable.
local root = app.params["source-root"] or app.fs.currentPath
local extension = app.fs.joinPath(root, "aseprite-extension")
local function module(name) return dofile(app.fs.joinPath(extension, "lib", name .. ".lua")) end
local deps = { presets = module("presets"), settings = module("settings"),
  palette = module("palette"), runner = module("runner"), output = module("output"), geometry = module("geometry") }
local processing = module("processing")
deps.presets.configure(extension)
local plugin = { path = app.params["plugin-root"] or extension }
local count = 0
local function test(name, run)
  local ok, problem = xpcall(run, debug.traceback)
  assert(ok, name .. ": " .. tostring(problem))
  count = count + 1
  print("PASS: " .. name)
end
local pc = app.pixelColor
local colors = { pc.rgba(0, 0, 0, 0), pc.rgba(220, 40, 20, 128),
  pc.rgba(30, 190, 60, 255), pc.rgba(40, 80, 220, 255) }
local function fixture(mode)
  local source = Sprite(64, 64, mode or ColorMode.RGB)
  source.filename = "Fixture with spaces.aseprite"
  local image = Image(64, 64, source.colorMode)
  if source.colorMode == ColorMode.INDEXED then
    local palette = Palette(4)
    -- A transparent index can have opaque palette metadata; it is still omitted.
    for i = 0, 3 do palette:setColor(i, Color { r=i*60, g=255-i*60, b=30, a=255 }) end
    source:setPalette(palette)
    source.transparentColor = 0
  end
  for pixel in image:pixels() do
    local index = math.floor(pixel.x / 32) + 2 * math.floor(pixel.y / 32)
    if source.colorMode == ColorMode.RGB then pixel(colors[index+1])
    elseif source.colorMode == ColorMode.INDEXED then pixel(index)
    else pixel(pc.graya(index*70, index == 0 and 0 or index == 1 and 128 or 255)) end
  end
  source.cels[1].image = image
  return source
end
local function snapshot(source)
  local result = { source.filename, source.width, source.height, source.colorMode,
    #source.layers, #source.frames, source.isModified, source.undoHistory.undoSteps }
  for _, cel in ipairs(source.cels) do
    result[#result+1] = cel.image.id
    result[#result+1] = cel.image.version
    result[#result+1] = cel.image.bytes
    result[#result+1] = cel.position.x
    result[#result+1] = cel.position.y
  end
  return result
end
local function unchanged(source, before)
  local after = snapshot(source)
  assert(#before == #after)
  for i, value in ipairs(before) do assert(value == after[i], "Source changed at snapshot field " .. i) end
end
local function run(source, values, frame)
  local before = snapshot(source)
  local result, problem, warning = processing.run(plugin, source, frame or 1,
    values or deps.presets.defaults("generic"), deps)
  assert(result, problem)
  assert(not warning, warning)
  unchanged(source, before)
  assert(result ~= source and result.colorMode == ColorMode.RGB)
  assert(not result.hasAssociatedFile and result.isModified)
  assert(result.filename == "Fixture with spaces-snapped")
  assert(#result.frames == 1 and #result.layers == 1 and result.layers[1].name == "Snapped")
  return result
end
local function alphas(image)
  local result = {}
  for pixel in image:pixels() do result[pc.rgbaA(pixel())] = true end
  return result
end

test("platform lookup and missing binary errors", function()
  assert(deps.runner.resolve(plugin.path, {windows=true, x64=true}))
  for _, platform in ipairs({{linux=true,x64=true}, {macos=true,arm64=true}, {windows=true,x86=true}, {}}) do
    local path, problem = deps.runner.resolve(plugin.path, platform)
    assert(not path and problem == "Pixel Snapper native binary is not available for this platform yet.")
  end
  local path, problem = deps.runner.resolve(app.fs.joinPath(root, "target", "no-such-extension"), {windows=true,x64=true})
  assert(not path and problem:find("executable is missing", 1, true))
end)

test("command rejects shell input and omits Auto override", function()
  local files = { input="C:\\Temp Dir\\input image.png", output="C:\\Temp Dir\\output image.png", log="C:\\Temp Dir\\process.log" }
  local values = deps.presets.defaults("generic")
  local executable = "C:\\Extension & (test)\\engine.exe"
  local command = deps.runner.command(executable, files, values)
  assert(not command:find("--pixel-size",1,true) and not command:find("--palette",1,true))
  values.pixel_size_mode = "Manual"
  assert(deps.runner.command(executable, files, values, "112233,445566"):find("--pixel-size 8 --palette 112233,445566",1,true))
  for _, path in ipairs({ 'C:\\bad" & calc', 'C:\\%TEMP%\\bad', 'C:\\bad!path', 'C:\\bad\npath', 'relative.exe' }) do
    assert(not pcall(deps.runner.command, path, files, values))
  end
  assert(not pcall(deps.runner.command, executable, files, values, "112233 & calc"))
  values.color_count = "16 & calc"
  assert(not pcall(deps.runner.command, executable, files, values))
end)

test("active frame rendering composites layers without mutating source", function()
  local source = fixture()
  source:newEmptyFrame(2)
  local second = Image(64,64,ColorMode.RGB)
  second:clear(pc.rgba(10,20,30,255))
  source:newCel(source.layers[1], 2, second)
  local overlay = source:newLayer()
  local patch = Image(8,8,ColorMode.RGB)
  patch:clear(pc.rgba(200,100,50,255))
  source:newCel(overlay,2,patch,Point(7,9))
  local hidden = source:newLayer()
  hidden.isVisible = false
  source:newCel(hidden,2,patch,Point(0,0))
  app.activeFrame = source.frames[2]
  local before = snapshot(source)
  local rendered = processing.render(source,2)
  assert(rendered:getPixel(7,9) == pc.rgba(200,100,50,255))
  assert(rendered:getPixel(0,0) == pc.rgba(10,20,30,255))
  unchanged(source,before)
  local result = run(source,nil,2)
  result:close()
  source:close()
end)

test("Generic Auto creates an unsaved RGBA sprite and preserves alpha", function()
  local source = fixture()
  local result = run(source)
  local alpha = alphas(result.cels[1].image)
  assert(alpha[0] and alpha[128] and alpha[255])
  print("Auto fixture output: " .. result.width .. " x " .. result.height)
  result:close(); source:close()
end)

test("Manual pixel size and custom palette run through the real CLI", function()
  local source = fixture()
  local values = deps.presets.defaults("generic")
  values.pixel_size_mode, values.manual_pixel_size = "Manual", 8
  values.palette_mode, values.custom_palette = "Custom HEX Palette", "112233, AABBCC"
  local result = run(source,values)
  for pixel in result.cels[1].image:pixels() do
    local color = pixel()
    if pc.rgbaA(color) > 0 then
      local hex = string.format("%02x%02x%02x", pc.rgbaR(color),pc.rgbaG(color),pc.rgbaB(color))
      assert(hex == "112233" or hex == "aabbcc",hex)
    end
  end
  local alpha = alphas(result.cels[1].image)
  assert(alpha[0] and alpha[128] and alpha[255])
  print("Manual fixture output: " .. result.width .. " x " .. result.height)
  result:close(); source:close()
end)

test("current palette skips transparent entries and keeps partial-alpha RGB", function()
  local source = fixture()
  local palette = Palette(4)
  palette:setColor(0,Color{r=1,g=2,b=3,a=0})
  palette:setColor(1,Color{r=17,g=34,b=51,a=128})
  palette:setColor(2,Color{r=170,g=187,b=204,a=255})
  palette:setColor(3,Color{r=17,g=34,b=51,a=255})
  source:setPalette(palette)
  assert(deps.palette.current(source,1,deps.settings) == "112233,aabbcc")
  local values = deps.presets.defaults("generic")
  values.palette_mode = "Current Aseprite Palette"
  local result = run(source,values)
  for pixel in result.cels[1].image:pixels() do
    local value = pixel()
    if pc.rgbaA(value)>0 then
      assert((pc.rgbaR(value)==17 and pc.rgbaG(value)==34 and pc.rgbaB(value)==51)
        or (pc.rgbaR(value)==170 and pc.rgbaG(value)==187 and pc.rgbaB(value)==204))
    end
  end
  result:close()
  for i=0,3 do palette:setColor(i,Color{r=i,g=0,b=0,a=0}) end
  source:setPalette(palette)
  assert(deps.palette.current(source,1,deps.settings) == nil)
  source:close()
end)

test("indexed and grayscale sources export as RGBA with transparency", function()
  for _,mode in ipairs({ColorMode.INDEXED,ColorMode.GRAY}) do
    local source = fixture(mode)
    local rendered = processing.render(source,1)
    assert(rendered.colorMode == ColorMode.RGB and pc.rgbaA(rendered:getPixel(0,0))==0)
    local values = deps.presets.defaults("generic")
    if mode == ColorMode.INDEXED then
      values.palette_mode = "Current Aseprite Palette"
      local hex = deps.palette.current(source,1,deps.settings)
      assert(not hex:find("00ff1e",1,true))
    end
    local result = run(source,values)
    local alpha = alphas(result.cels[1].image)
    assert(alpha[0] and alpha[255])
    result:close(); source:close()
  end
end)

test("engine failure reports its exit code and cleans the temporary workspace", function()
  local files = deps.runner.workspace(0)
  local handle = assert(io.open(files.input,"wb"))
  handle:write("invalid PNG fixture"); handle:close()
  local ok, problem = pcall(deps.runner.execute, assert(deps.runner.resolve(plugin.path)), files, deps.presets.defaults("generic"))
  assert(not ok and tostring(problem):find("exit code 1",1,true),tostring(problem))
  assert(not app.fs.isFile(files.output))
  assert(not deps.runner.cleanup(files))
  assert(not app.fs.isDirectory(files.directory))
end)

test("validation failures create no output and leave source unchanged", function()
  local source = fixture()
  local before = snapshot(source)
  local document_count = #app.sprites
  for _,values in ipairs({deps.presets.defaults("scaleweave-terrain-64"), deps.presets.defaults("generic")}) do
    if values.sizing_mode ~= "Native" then values.width = 0 end
    if values.sizing_mode == "Native" then values.manual_pixel_size="1.5"; values.pixel_size_mode="Manual" end
    local result,problem = processing.run(plugin,source,1,values,deps)
    assert(not result and problem and #app.sprites==document_count)
    unchanged(source,before)
  end
  source:close()
end)

test("successful exit without output and failure with output cannot open bogus sprites", function()
  local execute = os.execute
  local source = fixture()
  local before = snapshot(source)
  local document_count = #app.sprites
  local files = deps.runner.workspace(source.id)
  local ok, problem = xpcall(function()
    os.execute = function() return true, "exit", 0 end
    local accepted, failure = pcall(deps.runner.execute, assert(deps.runner.resolve(plugin.path)), files, deps.presets.defaults("generic"))
    assert(not accepted and tostring(failure):find("did not create an output PNG",1,true))
    fixture():close() -- Document creation/closing elsewhere must not affect safety checks.
    processing.render(source,1):saveAs(files.output)
    os.execute = function() return nil, "exit", 7 end
    accepted, failure = pcall(deps.runner.execute, assert(deps.runner.resolve(plugin.path)), files, deps.presets.defaults("generic"))
    assert(not accepted and tostring(failure):find("exit code 7",1,true))
    os.execute = function() return true, "exit", 0 end
    local result, failed = processing.run(plugin,source,1,deps.presets.defaults("generic"),deps)
    assert(not result and failed:find("did not create an output PNG",1,true))
    assert(#app.sprites==document_count)
    unchanged(source,before)
  end,debug.traceback)
  os.execute = execute
  assert(not deps.runner.cleanup(files))
  source:close()
  assert(ok,problem)
end)

test("every sizing mode runs after the CLI without changing its arguments or source", function()
  local source = fixture()
  local native = run(source)
  local native_image = native.cels[1].image
  local files = {input="C:\\Temp Dir\\input.png", output="C:\\Temp Dir\\output.png", log="C:\\Temp Dir\\process.log"}
  local values = deps.presets.defaults("generic")
  local command = deps.runner.command("C:\\Engine\\engine.exe",files,values)
  for _, mode in ipairs({"Exact", "Fit + Pad", "Crop"}) do
    values.sizing_mode, values.width, values.height = mode, 23, 17
    assert(deps.runner.command("C:\\Engine\\engine.exe",files,values) == command)
    local result = run(source,values)
    assert(result.width==23 and result.height==17)
    assert(result.cels[1].image.bytes==deps.output.apply(native_image,values).bytes)
    result:close()
  end
  local feature = run(source,deps.presets.defaults("scaleweave-feature-64"))
  assert(feature.width==64 and feature.height==64)
  local terrain = run(source,deps.presets.defaults("scaleweave-terrain-64"))
  assert(terrain.width==64 and terrain.height==64)
  assert(pc.rgbaA(terrain.cels[1].image:getPixel(0,0))==0)
  values.hex_mask, values.preserve_alpha, values.background = true, false, "123456"
  local flattened = run(source,values)
  assert(pc.rgbaA(flattened.cels[1].image:getPixel(0,0))==0)
  assert(pc.rgbaA(flattened.cels[1].image:getPixel(11,8))==255)
  flattened:close(); terrain:close(); feature:close(); native:close(); source:close()
end)

test("output-stage failure cleans files and opens no document", function()
  local source = fixture()
  local before, document_count = snapshot(source), #app.sprites
  local failing = {}
  for key,value in pairs(deps) do failing[key]=value end
  failing.output = {apply=function() error("Simulated output sizing failure") end}
  local result,problem = processing.run(plugin,source,1,deps.presets.defaults("generic"),failing)
  assert(not result and problem:find("Simulated output sizing failure",1,true))
  assert(#app.sprites==document_count and app.activeSprite==source)
  unchanged(source,before)
  source:close()
end)

test("all run directories were cleaned after success and failure", function()
  local path = app.fs.joinPath(app.fs.tempPath,"aseprite-pixelsnapper")
  assert(#app.fs.listFiles(path)==0,"Temporary files remain in "..path)
end)

print("PIXEL_SNAPPER_PROCESSING_OK: " .. count .. " checks passed")
