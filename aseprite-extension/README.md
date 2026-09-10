# Pixel Snapper for Aseprite

This fork adds an Aseprite frontend for **Sprite Fusion Pixel Snapper**, the
Rust image-processing engine by **Hugo Duprez**. The engine remains authoritative;
the extension contains no Lua snapping or palette-quantization algorithm.

## Development checkpoint: native processing

Version `0.1.0-dev.2` processes the active frame with the existing Rust executable
on Windows x64. It includes the command, preset system, validation, and saved
preferences. **Sizing and masking are not implemented yet.** For now, choose
Generic / Detected Grid or set Native sizing, Preserve Alpha on, and Hex Mask off.
Other output combinations show a clear message before export or execution.
There is no release archive yet; the development setup below supplies the binary.

Open a sprite and choose **Sprite > Pixel Snapper...**. The command is disabled
without an active sprite. **Snap** exports a separate rendered RGBA image of the
active frame to a unique directory under `app.fs.tempPath/aseprite-pixelsnapper`,
runs the native engine, and opens the result as an unsaved, editable RGB sprite
with alpha and a `-snapped` title. Visible layers are composited; other frames are
not processed. Indexed and grayscale sources are also rendered to RGBA.

Successful processing remembers the current controls and preset through
`plugin.preferences`. Cancel or closing the dialog discards these edits.
The source sprite is not modified. Temporary PNGs and logs are removed after
success and handled errors; cleanup failures are reported. A crash or forced
termination can leave that run's directory behind.

Aseprite may request permission to execute the bundled program and access
temporary files. Allow the operation to process an image. Denying permission
stops processing with an error and does not create an output sprite. Processing
is synchronous, so Aseprite waits until the engine exits; there is no live preview
or mid-process Cancel. No network access or runtime download is used.

| Preset | Colors | Sizing | Alpha | Pointy hex mask |
| --- | --- | --- | --- | --- |
| Generic / Detected Grid | 16 | Native | Preserve | Off |
| Scaleweave Terrain 64 | 32 | Fit + Pad, 64 x 64 | Preserve | On |
| Scaleweave Feature 64 | 32 | Fit + Pad, 64 x 64 | Preserve | Off |
| Custom | Keeps current controls | Editable | Editable | Editable |

The table describes preset defaults; the two Scaleweave output configurations
will become functional when sizing/masking is added in the next checkpoint.
All built-ins start with Auto pixel size, Auto palette, and New Sprite output.
Dimensions remain editable for non-Native sizing. Selecting a built-in loads a
fresh copy of its defaults. Editing controls marks it customized; it never edits
the preset definition. Selecting Custom keeps the current controls.

## Controls

- **Colors:** a positive whole number. In this engine, quantization happens before
  snapping even when a custom palette is supplied. The palette maps colors after
  snapping; Colors stays relevant in all three palette modes.
- **Pixel Size:** Auto omits `--pixel-size`; Manual passes a whole number from
  1 through half the smaller input dimension. This guides grid detection and does
  not guarantee an output size of input size divided by this number.
- **Palette:** Auto, Current Aseprite Palette, or Custom HEX Palette. Custom text
  accepts comma-separated six-digit RGB colors, optionally surrounded by spaces,
  for example `0d2b45,ffecd6`. Validation deduplicates colors and permits at most
  256 distinct colors. No `#`, alpha, empty entries, or shell text is accepted.
  Current Aseprite Palette uses the active frame's palette, skips fully transparent
  entries and the indexed transparent index on sprites without a background layer,
  and deduplicates RGB values. Partially transparent entries contribute RGB only;
  image alpha remains independent. An empty usable palette gives an error.
- **Output:** Native, Exact, Fit + Pad, or Crop. These are future Aseprite
  post-processing choices, separate from Rust snapping. Exact can alter aspect
  ratio. Fit + Pad will center an aspect-preserving nearest-neighbor resize on a
  transparent canvas. Crop will center without scaling and pad if smaller.
  This frontend limits target dimensions to 1–10000 pixels per axis.
- **Preserve Alpha / Pointy Hex Mask:** saved output options; these are not Rust
  CLI flags and are not applied in this settings-only checkpoint.

## Developer checks

Build the engine and put it in the development extension directory:

```powershell
cargo build --release --locked
New-Item -ItemType Directory -Force aseprite-extension/bin/windows-x64
Copy-Item target/release/spritefusion-pixel-snapper.exe aseprite-extension/bin/windows-x64/
```

For a local development installation, copy the contents of `aseprite-extension/`
into an Aseprite `extensions/pixel-snapper/` directory, also copy the repository's
`LICENSE` into that directory, and restart Aseprite. Keep any existing `__pref.lua`
when updating. The binary directory is generated and gitignored. Packaged end
users will not need Rust; building and packaging a release comes later.

Executable and temporary paths containing spaces, ampersands, and parentheses
have been tested. Paths containing `%`, `!`, quotes, or control characters are
rejected before execution because Windows shell expansion can change them. Source
artwork filenames are never inserted into the shell command.

The settings regression checks use Aseprite's own Lua interpreter without extra
dependencies. Run from the repository root in PowerShell:

```powershell
& 'C:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe' --batch --script tests/aseprite-settings.lua
& 'C:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe' --batch --script tests/aseprite-processing.lua
```

Change the Aseprite executable path for your installation. The processing suite
requires the built binary above, or a staged directory supplied with
`--script-param 'plugin-root=C:\path to extension'` before `--script`.
It uses generated fixtures and no additional test dependencies. See
[architecture and verification notes](../docs/ASEPRITE_EXTENSION.md).

## Attribution and license

The original Sprite Fusion Pixel Snapper engine is by Hugo Duprez:
<https://github.com/Hugo-Dz/spritefusion-pixel-snapper>.
The Aseprite frontend and presets are additions by KoalaNalle in this fork.
The new extension code is MIT-licensed. The repository's upstream `LICENSE`,
including `Copyright (c) 2025 Hugo Duprez`, is unchanged and must accompany
extension distributions and bundled engine binaries. Engine version `1.0.0`
at the inspected commit `ae20461f60fb39e75d15f184bab1ebec1219511c` is separate from
the extension version.
