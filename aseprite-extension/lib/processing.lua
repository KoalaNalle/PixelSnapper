-- SPDX-License-Identifier: MIT
local M = {}

function M.render(source, frame_number)
  if not source or not source.isValid or not source.frames[frame_number] then
    error("The source sprite or selected frame is no longer available.", 0)
  end
  local image = Image(source.width, source.height, ColorMode.RGB)
  image:clear()
  image:drawSprite(source, frame_number)
  return image
end

function M.new_sprite(image, source)
  local result = Sprite(image.spec)
  local ok, problem = pcall(function()
    result.layers[1].name = "Snapped"
    result.cels[1].image = image
    result.colorSpace = source.colorSpace
    result.filename = (app.fs.fileTitle(source.filename) ~= "" and app.fs.fileTitle(source.filename) or "sprite") .. "-snapped"
  end)
  if not ok then result:close(); error(problem, 0) end
  return result
end

function M.run(plugin, source, frame_number, values, dependencies)
  local files
  local result
  local runner = dependencies.runner
  local ok, problem = pcall(function()
    local clean, validation = dependencies.settings.validate(values, source, dependencies.presets)
    if not clean then error(validation, 0) end
    local executable, missing = runner.resolve(plugin.path)
    if not executable then error(missing, 0) end
    local palette_hex, palette_problem = dependencies.palette.resolve(source, frame_number, clean, dependencies.settings)
    if palette_problem then error(palette_problem, 0) end
    files = runner.workspace(source.id)
    -- Reject unsafe paths before exporting or invoking the process.
    runner.command(executable, files, clean, palette_hex)
    local input = M.render(source, frame_number)
    input:saveAs(files.input)
    if not app.fs.isFile(files.input) then error("Could not export the active frame to a temporary PNG.", 0) end
    runner.execute(executable, files, clean, palette_hex)
    local image = Image { fromFile = files.output }
    if not image or image.colorMode ~= ColorMode.RGB then
      error("Pixel Snapper did not produce a readable RGBA PNG.", 0)
    end
    image = dependencies.output.apply(image, clean, dependencies.geometry)
    result = M.new_sprite(image, source)
  end)
  local cleanup_warning = runner.cleanup(files)
  if not ok then
    if source and source.isValid then
      app.activeSprite = source
      if source.frames[frame_number] then app.activeFrame = source.frames[frame_number] end
    end
    return nil, tostring(problem) .. (cleanup_warning and "\n" .. cleanup_warning or "")
  end
  app.activeSprite = result
  return result, nil, cleanup_warning
end

return M
