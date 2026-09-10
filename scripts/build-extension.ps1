[CmdletBinding()]
param([switch]$Development, [switch]$RequireClean)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$dist = Join-Path $root 'dist'
$source = Join-Path $root 'aseprite-extension'
Push-Location $root
try {
    $manifest = Get-Content -LiteralPath (Join-Path $source 'package.json') -Raw | ConvertFrom-Json
    $version = $manifest.version
    if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw 'Invalid extension version' }
    $dirty = [bool](git status --porcelain)
    if ($RequireClean -and $dirty) { throw 'Release packaging requires a clean working tree' }
    $profile = if ($Development) { 'development' } else { 'shipping' }
    $stage = [IO.Path]::GetFullPath((Join-Path $dist ('stage-' + $profile)))
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    if (!$stage.StartsWith($dist + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe staging path' }
    if (Test-Path -LiteralPath $stage) {
        if ((Get-Item -LiteralPath $stage).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Staging must not be a link' }
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Join-Path $stage 'lib'),(Join-Path $stage 'bin/windows-x64'),(Join-Path $stage 'licenses') -Force | Out-Null

    $originalFlags = $env:RUSTFLAGS
    $originalEncodedFlags = $env:CARGO_ENCODED_RUSTFLAGS
    try {
        # A release must not depend on a separately installed Visual C++ runtime.
        $env:CARGO_ENCODED_RUSTFLAGS = $null
        $env:RUSTFLAGS = '-C target-feature=+crt-static'
        & cargo build --release --locked --target x86_64-pc-windows-msvc --bin spritefusion-pixel-snapper | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Rust release build failed' }
    } finally {
        $env:RUSTFLAGS = $originalFlags
        $env:CARGO_ENCODED_RUSTFLAGS = $originalEncodedFlags
    }
    $binary = Join-Path $stage 'bin/windows-x64/spritefusion-pixel-snapper.exe'
    Copy-Item -LiteralPath (Join-Path $root 'target/x86_64-pc-windows-msvc/release/spritefusion-pixel-snapper.exe') -Destination $binary
    Copy-Item -LiteralPath (Join-Path $source 'package.json') -Destination $stage
    Get-ChildItem -LiteralPath $source -Filter '*.lua' -File | Copy-Item -Destination $stage
    Get-ChildItem -LiteralPath (Join-Path $source 'lib') -Filter '*.lua' -File |
        Where-Object { $Development -or $_.Name -ne 'presets-development.lua' } |
        Copy-Item -Destination (Join-Path $stage 'lib')
    foreach ($notice in @('LICENSE','LICENSE-EXTENSION','THIRD_PARTY_NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $root $notice) -Destination $stage
    }
    Copy-Item -LiteralPath (Join-Path $root 'docs/USER_GUIDE.md') -Destination (Join-Path $stage 'README.md')

    # Copy the actual license/notice files from the locked native dependency graph.
    $metadataText = & cargo metadata --locked --format-version 1 --filter-platform x86_64-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect locked dependency metadata' }
    $metadata = ($metadataText -join "`n") | ConvertFrom-Json
    $dependencies = @()
    foreach ($package in $metadata.packages | Where-Object source | Sort-Object name) {
        $directory = Split-Path -Parent $package.manifest_path
        $notices = @(Get-ChildItem -LiteralPath $directory -File | Where-Object { $_.Name -match '^(LICEN[CS]E|COPYING|NOTICE|UNLICENSE)' })
        if (!$notices.Count) { throw ('No dependency license files found: ' + $package.name) }
        $destination = Join-Path $stage ('licenses/' + $package.name + '-' + $package.version)
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        $notices | Copy-Item -Destination $destination
        $dependencies += [ordered]@{name=$package.name; version=$package.version; license=$package.license; repository=$package.repository}
    }
    $dependencies | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'licenses/dependencies.json') -Encoding utf8
    $sysroot = & rustc --print sysroot
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate Rust notices' }
    $rustNotices = Join-Path $sysroot 'share/doc/rust'
    $rustDestination = Join-Path $stage 'licenses/rust'
    New-Item -ItemType Directory -Path $rustDestination -Force | Out-Null
    foreach ($notice in @('COPYRIGHT.html','COPYRIGHT-library.html')) {
        Copy-Item -LiteralPath (Join-Path $rustNotices $notice) -Destination $rustDestination
    }

    # Use the installed build tools to check the shipped PE, not just build flags.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $dumpbin = Get-ChildItem -LiteralPath (Join-Path $installation 'VC/Tools/MSVC') -Directory |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'bin/Hostx64/x64/dumpbin.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (!$dumpbin) { throw 'dumpbin is required to verify the native runtime dependencies' }
    $importsText = & $dumpbin /DEPENDENTS $binary
    if ($LASTEXITCODE -ne 0) { throw 'Native dependency inspection failed' }
    $imports = @($importsText | ForEach-Object { if ($_ -match '^\s+([\w.-]+\.dll)\s*$') { $Matches[1] } })
    if (!$imports.Count -or ($imports | Where-Object { $_ -match '^(VCRUNTIME|MSVCP|ucrtbase|api-ms-win-crt)' })) { throw 'Executable still requires a separately supplied C runtime' }
    $pe = [IO.File]::ReadAllBytes($binary)
    $peOffset = [BitConverter]::ToInt32($pe,0x3c)
    if ([BitConverter]::ToUInt16($pe,$peOffset+4) -ne 0x8664) { throw 'Native executable is not Windows x64' }
    $engine = $metadata.packages | Where-Object name -eq 'spritefusion-pixel-snapper'
    $info = [ordered]@{
        extensionVersion=$version; profile=$profile; engineVersion=$engine.version
        repository='https://github.com/KoalaNalle/PixelSnapper'; sourceCommit=(git rev-parse HEAD)
        sourceDirty=$dirty; engineSourceCommit=(git log -1 --format=%H -- Cargo.toml Cargo.lock src)
        engineSourceTree=(git rev-parse HEAD:src); engineBaselineCommit='ae20461f60fb39e75d15f184bab1ebec1219511c'
        rustc=(& rustc --version); target='x86_64-pc-windows-msvc'; staticCrt=$true
        importedDlls=$imports; binarySha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $info | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'BUILD-INFO.json') -Encoding utf8
    $suffix = if ($Development) { '-Development' } else { '' }
    $archive = Join-Path $dist ('PixelSnapper-Aseprite-' + $version + $suffix + '.aseprite-extension')
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stage,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
    $checksum = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$checksum  $([IO.Path]::GetFileName($archive))" | Set-Content -LiteralPath ($archive + '.sha256') -Encoding ascii
    Write-Host ('Packaged: ' + $archive)
    [pscustomobject]@{Archive=$archive; Stage=$stage; Binary=$binary; Version=$version; Profile=$profile}
} finally { Pop-Location }
