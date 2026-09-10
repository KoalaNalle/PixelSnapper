-- SPDX-License-Identifier: MIT
-- Only this module constructs commands or invokes the native engine.
local M = {}
local counter = 0
local unavailable = "Pixel Snapper native binary is not available for this platform yet."

function M.resolve(plugin_path, platform)
  platform = platform or app.os
  local os_name = platform.windows and "windows" or platform.macos and "macos"
    or platform.linux and "linux"
  local arch = platform.arm64 and "arm64" or platform.x64 and "x64"
    or platform.x86 and "x86"
  -- Add another tested launcher here when that platform's binary is distributed.
  if os_name ~= "windows" or arch ~= "x64" then return nil, unavailable end
  local executable = app.fs.joinPath(plugin_path, "bin", os_name .. "-" .. arch,
    "spritefusion-pixel-snapper.exe")
  if not app.fs.isFile(executable) then
    return nil, "Pixel Snapper's Windows executable is missing. Reinstall the complete extension.\nExpected: " .. executable
  end
  return executable
end

local function quote_path(path)
  -- CMD expands %variables% even inside quotes; ! can expand with delayed
  -- expansion. Reject those rare path characters instead of altering the path.
  if type(path) ~= "string" or path == "" or path:find('["%%!%c]') then
    error('Cannot safely run Pixel Snapper from a path containing quotes, %, !, or control characters.', 0)
  end
  if not path:match("^%a:[/\\]") and not path:match("^\\\\") then
    error("Pixel Snapper requires absolute executable and temporary paths.", 0)
  end
  return '"' .. path .. '"'
end

local function integer_argument(value)
  if type(value) ~= "number" or value <= 0 or value ~= math.floor(value) then
    error("Invalid numeric CLI argument.", 0)
  end
  local text = tostring(math.tointeger(value))
  if not text:match("^%d+$") then error("Invalid numeric CLI argument.", 0) end
  return text
end

function M.command(executable, files, values, palette_hex)
  local parts = { quote_path(executable), quote_path(files.input), quote_path(files.output),
    integer_argument(values.color_count) }
  if values.pixel_size_mode == "Manual" then
    parts[#parts + 1] = "--pixel-size"
    parts[#parts + 1] = integer_argument(values.manual_pixel_size)
  elseif values.pixel_size_mode ~= "Auto" then
    error("Invalid pixel-size mode.", 0)
  end
  if palette_hex ~= nil then
    if type(palette_hex) ~= "string" or palette_hex == "" then error("Invalid RGB palette argument.", 0) end
    local count = 0
    for color in (palette_hex .. ","):gmatch("(.-),") do
      if not color:match("^%x%x%x%x%x%x$") then error("Invalid RGB palette argument.", 0) end
      count = count + 1
    end
    if count > 256 then error("Too many RGB palette colors.", 0) end
    parts[#parts + 1] = "--palette"
    parts[#parts + 1] = palette_hex
  end
  -- Windows system()/CMD needs the outer quotes around a quoted executable.
  -- Every path is quoted, numbers are integers, palette tokens are RGB hex only.
  local command = '"' .. table.concat(parts, " ") .. " > " .. quote_path(files.log) .. ' 2>&1"'
  if #command > 8000 then error("Pixel Snapper's command exceeds the Windows command length limit.", 0) end
  return command
end

function M.workspace(sprite_id)
  local root = app.fs.joinPath(app.fs.tempPath, "aseprite-pixelsnapper")
  if not app.fs.isDirectory(root) then app.fs.makeAllDirectories(root) end
  if not app.fs.isDirectory(root) then error("Could not create Pixel Snapper's temporary directory.", 0) end
  for _ = 1, 10 do
    counter = counter + 1
    local name = string.format("run-%d-%d-%d-%d-%d", os.time(), sprite_id, counter,
      math.random(1, 1073741823), math.random(1, 1073741823))
    local directory = app.fs.joinPath(root, name)
    if not app.fs.isDirectory(directory) and app.fs.makeDirectory(directory) then
      return { directory = directory, input = app.fs.joinPath(directory, "input.png"),
        output = app.fs.joinPath(directory, "snapped.png"), log = app.fs.joinPath(directory, "process.log") }
    end
  end
  error("Could not create a unique Pixel Snapper temporary directory.", 0)
end

function M.cleanup(files)
  if not files then return nil end
  local remaining = {}
  for _, key in ipairs({ "input", "output", "log" }) do
    local ok = pcall(function()
      if app.fs.isFile(files[key]) then os.remove(files[key]) end
      return not app.fs.isFile(files[key])
    end)
    if not ok or app.fs.isFile(files[key]) then remaining[#remaining + 1] = files[key] end
  end
  -- Only our three known files and then this empty run directory are removed.
  local ok, removed = pcall(app.fs.removeDirectory, files.directory)
  if not ok or not removed then remaining[#remaining + 1] = files.directory end
  if #remaining > 0 then return "Some temporary files could not be removed:\n" .. table.concat(remaining, "\n") end
end

local function read_log(path)
  local ok, result = pcall(function()
    local file = io.open(path, "rb")
    if not file then return "" end
    local text = file:read(4000) or ""
    file:close()
    return text:gsub("\r", "")
  end)
  return ok and result or ""
end

function M.execute(executable, files, values, palette_hex)
  local command = M.command(executable, files, values, palette_hex)
  local ok, reason, code = os.execute(command)
  -- Lua 5.4 returns true/nil, 'exit'/'signal', code. Accept numeric status
  -- too, for builds that expose the older system() return convention.
  local success = ok == true or (type(ok) == "number" and ok == 0)
  local status = type(code) == "number" and code or type(ok) == "number" and ok or nil
  local diagnostics = read_log(files.log)
  if not success then
    error("Pixel Snapper failed" .. (status and " (exit code " .. status .. ")" or " (no exit code available)")
      .. "." .. (diagnostics ~= "" and "\n" .. diagnostics or "\nCheck Aseprite's executable permission and the bundled native binary."), 0)
  end
  if not app.fs.isFile(files.output) or app.fs.fileSize(files.output) == 0 then
    error("Pixel Snapper exited successfully but did not create an output PNG.\n" .. diagnostics, 0)
  end
  return diagnostics
end

return M
