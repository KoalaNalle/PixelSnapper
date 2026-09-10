[CmdletBinding()]
param([string]$AsepritePath, [switch]$RequireClean)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $root
try {
    & cargo test --locked | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Rust tests failed' }
    $package = & (Join-Path $PSScriptRoot 'build-extension.ps1') -RequireClean:$RequireClean
    & $package.Binary --help | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'CLI help failed' }
    $work = [IO.Path]::GetFullPath((Join-Path $root 'dist/smoke-test'))
    if (!$work.StartsWith((Join-Path $root 'dist') + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe smoke-test directory' }
    if (Test-Path -LiteralPath $work) {
        if ((Get-Item -LiteralPath $work).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Smoke-test directory must not be a link' }
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    Add-Type -AssemblyName System.Drawing
    $fixture = New-Object System.Drawing.Bitmap 16,16
    try {
        for ($y=0; $y -lt 16; $y++) { for ($x=0; $x -lt 16; $x++) {
            $alpha = if ($x -lt 4) { 0 } else { 255 }
            $red = if ($x -lt 8) { 40 } else { 200 }
            $green = if ($y -lt 8) { 150 } else { 40 }
            $fixture.SetPixel($x,$y,[Drawing.Color]::FromArgb($alpha,$red,$green,70))
        } }
        $inputPng = Join-Path $work 'input fixture.png'
        $fixture.Save($inputPng,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $fixture.Dispose() }
    $outputPng = Join-Path $work 'output fixture.png'
    & $package.Binary $inputPng $outputPng 4 --pixel-size 4 | Out-Host
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $outputPng)) { throw 'Native fixture processing failed' }
    $decoded = [Drawing.Image]::FromFile($outputPng)
    try { if ($decoded.Width -lt 1 -or $decoded.Height -lt 1) { throw 'Invalid processed dimensions' } } finally { $decoded.Dispose() }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($package.Archive)
    try {
        $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
        foreach ($required in @('package.json','pixel-snapper.lua','lib/output.lua','lib/geometry.lua','bin/windows-x64/spritefusion-pixel-snapper.exe','LICENSE','LICENSE-EXTENSION','THIRD_PARTY_NOTICES.md','BUILD-INFO.json','licenses/dependencies.json','licenses/rust/COPYRIGHT-library.html')) {
            if ($required -notin $names) { throw ('Missing archive entry: ' + $required) }
        }
        if ('lib/presets-development.lua' -in $names) { throw 'Development presets leaked into shipping archive' }
    } finally { $zip.Dispose() }
    $extracted = Join-Path $work 'extracted package with spaces'
    [IO.Compression.ZipFile]::ExtractToDirectory($package.Archive,$extracted)
    if ((Get-FileHash -LiteralPath (Join-Path $extracted 'LICENSE')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root 'LICENSE')).Hash) { throw 'Upstream license changed in archive' }
    if ((Get-FileHash -LiteralPath (Join-Path $extracted 'bin/windows-x64/spritefusion-pixel-snapper.exe')).Hash -ne (Get-FileHash -LiteralPath $package.Binary).Hash) { throw 'Archived executable differs from verified build' }
    if ($AsepritePath) {
        foreach ($check in @(@('settings','tests/aseprite-settings.lua','PIXEL_SNAPPER_SETTINGS_OK'),@('output','tests/aseprite-output.lua','PIXEL_SNAPPER_OUTPUT_OK'),@('processing','tests/aseprite-processing.lua','PIXEL_SNAPPER_PROCESSING_OK'),@('package','tests/aseprite-package.lua','PIXEL_SNAPPER_PACKAGE_OK'))) {
            $stdout = Join-Path $work ($check[0]+'.log')
            $stderr = Join-Path $work ($check[0]+'.err')
            $arguments = '--batch --script-param "plugin-root=' + $extracted + '" --script ' + $check[1]
            $process = Start-Process -FilePath $AsepritePath -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
            if (!$process.WaitForExit(60000)) { throw ('Aseprite check timed out: '+$check[0]) }
            $result = Get-Content -LiteralPath $stdout -Raw
            Write-Host $result
            if ($process.ExitCode -ne 0 -or !$result -or !$result.Contains($check[2])) { Get-Content -LiteralPath $stderr | Out-Host; throw ('Aseprite check failed: '+$check[0]) }
        }
    } else { Write-Host 'Aseprite checks skipped; pass -AsepritePath to include them.' }
    Write-Host 'PIXEL_SNAPPER_SMOKE_OK: build, Rust tests, help, PNG, archive layout, executable and notices'
    $package
} finally { Pop-Location }
