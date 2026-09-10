# Developing Pixel Snapper for Aseprite

[Project overview](../README.md) · [Controls](../aseprite-extension/README.md) ·
[Architecture and verification](ASEPRITE_EXTENSION.md)

This repository develops the Aseprite frontend around the retained Rust engine.
Keep image processing in Rust and optional output sizing/masking in Aseprite.
The CLI and WASM remain independently usable; their original instructions are
preserved in the [upstream README](upstream/README.md).

## Windows development setup

The tested application is Aseprite **1.3.18.5-x64**. Building the native engine
requires Rust with the Windows MSVC toolchain, the Visual Studio C++ build tools,
and a Windows SDK. The initial build and five engine tests passed with Rust
1.98.1. No new toolchain or dependency versions are required by the documentation
and fixture update.

From a checkout of `KoalaNalle/PixelSnapper`, run in PowerShell:

```powershell
cargo build --release --locked
if ($LASTEXITCODE -ne 0) { throw 'Rust build failed' }
New-Item -ItemType Directory -Force aseprite-extension/bin/windows-x64 | Out-Null
Copy-Item target/release/spritefusion-pixel-snapper.exe aseprite-extension/bin/windows-x64/
```

The extension's runner expects:

```text
aseprite-extension/bin/windows-x64/spritefusion-pixel-snapper.exe
```

That directory and `target/` are generated and gitignored. Do not commit binaries,
temporary run directories, staged packages, or release archives.

## Install the development extension locally

1. Close Aseprite before updating the installed extension.
2. Locate Aseprite's configuration directory. For a normal Windows installation
   this is `%APPDATA%\Aseprite`; portable installations may use another location.
3. Create `extensions/pixel-snapper/` there. Copy the **contents** of
   `aseprite-extension/`, including `package.json`, Lua modules, and the built
   `bin/` directory, into it.
4. Copy the repository's `LICENSE`, `LICENSE-EXTENSION`, and
   `THIRD_PARTY_NOTICES.md` into that same installed directory. Preserve an
   existing `__pref.lua` when updating so the user's preferences survive.
5. Start Aseprite, open an image, and choose **Sprite > Pixel Snapper...**.
   Use Generic / Detected Grid for the supported Native output defaults.

Approve Aseprite's file-access and external-program prompts when testing. Do
not change or bypass Aseprite's permission handling in the extension code.
The [official installation documentation](https://www.aseprite.org/docs/extensions/)
explains configuration directories and archive installation.

## Repeat the checks

Run from the repository root after building and copying the executable above:

```powershell
cargo test --locked
& 'C:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe' --batch --script tests/aseprite-settings.lua
& 'C:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe' --batch --script tests/aseprite-processing.lua
& 'C:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe' --batch --script test_img/run-aseprite.lua
```

Adjust the Aseprite path for your installation. Check each command's result
before continuing. The settings suite has 12 checks and the integration suite
has 11 checks. The latter uses the actual native executable for successful
processing cases. A staged extension can be tested by supplying
`--script-param 'plugin-root=C:\path to extension'` before its `--script` option.

The [swamp test](../test_img/README.md) uses a checked-in 640 x 640 PNG, so it
requires no image-generation dependencies. Its output images and logs remain
under the gitignored `test_img/output/`. The optional drawing generator uses
Node and Canvas only for development; neither is an extension runtime dependency.

See [verification results](ASEPRITE_EXTENSION.md#native-processing-checkpoint-verification-results)
for what has actually passed and which GUI/release checks remain unverified.

## Release work still pending

The current manual installation is not the final release pipeline. The packaging
checkpoint must add the build/package script and Windows smoke test, resolve the
MSVC runtime dependency, and produce an archive whose root contains `package.json`.
It must include the Windows executable, upstream and extension license texts,
attribution, and any required dependency notices. End users must not need Rust.

`dist/` is reserved for generated staging and archives. Record both the extension
version and the actual bundled engine version/commit. Do not bump the Rust crate
version for frontend-only changes, overwrite existing release assets, or publish
a release automatically.
