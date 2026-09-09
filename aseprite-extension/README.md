# Pixel Snapper for Aseprite

This fork adds an Aseprite frontend for **Sprite Fusion Pixel Snapper**, the
Rust image-processing engine by **Hugo Duprez**. The engine remains authoritative;
the extension contains no Lua snapping or palette-quantization algorithm.

## Development checkpoint: settings dialog

Version `0.1.0-dev.1` contains the command, preset system, validation, and saved
preferences. **It does not process images or include the native executable yet.**
The primary button is deliberately **Save Settings** at this checkpoint.
The first installable release will use **Snap** and bundle the native executable.

Open a sprite and choose **Sprite > Pixel Snapper...**. The command is disabled
without an active sprite. Save Settings remembers the current controls and preset
through `plugin.preferences`; Cancel or closing the dialog discards these edits.
Neither action modifies the source sprite.

| Preset | Colors | Sizing | Alpha | Pointy hex mask |
| --- | --- | --- | --- | --- |
| Generic / Detected Grid | 16 | Native | Preserve | Off |
| Scaleweave Terrain 64 | 32 | Fit + Pad, 64 x 64 | Preserve | On |
| Scaleweave Feature 64 | 32 | Fit + Pad, 64 x 64 | Preserve | Off |
| Custom | Keeps current controls | Editable | Editable | Editable |

All built-ins start with Auto pixel size, Auto palette, and New Sprite output.
Dimensions remain editable for non-Native sizing. Selecting a built-in loads a
fresh copy of its defaults. Editing controls marks it customized; it never edits
the preset definition. Selecting Custom keeps the current controls.

## Controls

- **Colors:** a positive whole number. In this engine, quantization happens before
  snapping even when a custom palette is supplied. The palette maps colors after
  snapping; Colors stays relevant in all three palette modes.
- **Pixel Size:** Auto omits `--pixel-size`; Manual will pass a whole number from
  1 through half the smaller input dimension. This guides grid detection and does
  not guarantee an output size of input size divided by this number.
- **Palette:** Auto, Current Aseprite Palette, or Custom HEX Palette. Custom text
  accepts comma-separated six-digit RGB colors, optionally surrounded by spaces,
  for example `0d2b45,ffecd6`. Validation deduplicates colors and permits at most
  256 distinct colors. No `#`, alpha, empty entries, or shell text is accepted.
  Reading the current sprite palette is part of the next processing checkpoint.
- **Output:** Native, Exact, Fit + Pad, or Crop. These are future Aseprite
  post-processing choices, separate from Rust snapping. Exact can alter aspect
  ratio. Fit + Pad will center an aspect-preserving nearest-neighbor resize on a
  transparent canvas. Crop will center without scaling and pad if smaller.
  This frontend limits target dimensions to 1–10000 pixels per axis.
- **Preserve Alpha / Pointy Hex Mask:** saved output options; these are not Rust
  CLI flags and are not applied in this settings-only checkpoint.

## Developer checks

The settings regression checks use Aseprite's own Lua interpreter without extra
dependencies. Run from the repository root in PowerShell:

```powershell
& 'C:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe' --batch --script tests/aseprite-settings.lua
```

Change the Aseprite executable path for your installation. Packaging, the native
runner, image import/export, output sizing/masking, and full installation QA are
scheduled for subsequent checkpoints. See [architecture notes](../docs/ASEPRITE_EXTENSION.md).

## Attribution and license

The original Sprite Fusion Pixel Snapper engine is by Hugo Duprez:
<https://github.com/Hugo-Dz/spritefusion-pixel-snapper>.
The Aseprite frontend and presets are additions by KoalaNalle in this fork.
The new extension code is MIT-licensed. The repository's upstream `LICENSE`,
including `Copyright (c) 2025 Hugo Duprez`, is unchanged and must accompany
extension distributions and bundled engine binaries. Engine version `1.0.0`
at the inspected commit `ae20461f60fb39e75d15f184bab1ebec1219511c` is separate from
the extension version.
