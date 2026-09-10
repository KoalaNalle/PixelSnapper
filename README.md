# Pixel Snapper for Aseprite

An Aseprite extension for turning inconsistent pixel art into an editable sprite
with a detected pixel grid and a controlled palette. Open an image, choose
**Sprite > Pixel Snapper...**, adjust the settings, and get a new sprite while
keeping your original untouched.

This fork maintains the **Aseprite frontend**. All snapping and palette
quantization use the existing [Sprite Fusion Pixel Snapper](https://github.com/Hugo-Dz/spritefusion-pixel-snapper)
Rust engine by **Hugo Duprez**. The original library, CLI, WASM support, tests,
and copyright notices remain in the repository.

## Current development version

**0.1.0-dev.2 · Windows x64 · Native output**

The extension can process the composited active frame, preserve transparency,
and open the result as a new, unsaved sprite. It supports Auto/Manual pixel size,
Auto/current/custom palettes, selectable presets, and remembered settings.
It has been tested in **Aseprite 1.3.18.5-x64**, including a successful run through
the installed extension's menu and dialog.

**Exact sizing, Fit + Pad, Crop, and the pointy hex mask are still pending.**
Their controls and preset defaults are present, but this development version
requires Native sizing, Preserve Alpha on, and Hex Mask off. Other output
combinations give a validation message before processing.

## Installation

The verified setup currently uses a local development installation. Follow the
[build and installation guide](docs/DEVELOPMENT.md) to build the Rust binary and
copy the extension into Aseprite. Packaging automation and installation from a
release archive have not yet been verified.

When a packaged `.aseprite-extension` asset is supplied, install it through
**Edit > Preferences > Extensions > Add Extension**, then restart Aseprite.
See [Aseprite's extension installation documentation](https://www.aseprite.org/docs/extensions/).
A GitHub **Source code (zip)** download is the repository, not an installable
extension package. Check the [releases page](https://github.com/KoalaNalle/PixelSnapper/releases)
for any packaged assets and their version-specific notes.

Release packages must include the native executable; end users should not need
Rust installed. Rust is needed for the current build-from-source setup.
macOS and Linux native integration are not available yet.

## Use Pixel Snapper

1. Open your image in Aseprite and select the frame you want to process.
2. Choose **Sprite > Pixel Snapper...**.
3. Select **Generic / Detected Grid** for the working defaults.
4. Choose your color count, pixel-size mode, and palette, then click **Snap**.
5. Approve Aseprite's temporary-file and external-program permissions when asked.
6. Edit or save the new `-snapped` sprite. The original remains unchanged.

Visible layers in the active frame are composited into an independent PNG.
Indexed and grayscale input are rendered to RGBA. The engine runs locally;
no network access, downloads, Python, or ComfyUI are used at runtime. Processing
is synchronous and successful runs clean up their temporary files.

## Settings and presets

- **Colors:** controls the Rust engine's initial quantization, including when
  a fixed palette is selected.
- **Pixel size:** Auto detects the grid; Manual supplies a positive whole-number
  override. Neither mode promises a specific output width or height.
- **Palette:** Auto, Current Aseprite Palette, or Custom HEX Palette such as
  `0d2b45,203c56,544e68,8d697a`. Palette entries supply RGB; image alpha is separate.
- **Preferences:** successful processing remembers your last settings. Selecting
  a preset restores its defaults; editing controls never changes the definition.

| Preset | Intended use | Output defaults | Current availability |
| --- | --- | --- | --- |
| Generic / Detected Grid | General snapping, 16 colors | Native, transparency preserved, no mask | Working |
| Scaleweave Terrain 64 | Terrain tiles, 32 colors | Fit + Pad to 64 x 64, pointy hex mask | Output processing pending |
| Scaleweave Feature 64 | Trees, rocks, landmarks, 32 colors | Fit + Pad to 64 x 64, no mask | Output processing pending |
| Custom | Keep and edit current controls | User-selected values | Working with Native / alpha on / mask off |

Scaleweave presets are optional frontend configurations. Target dimensions remain
editable, and every preset uses the same Rust snapping engine. Future resizing
and masking will run in Aseprite after snapping. See the
[full controls guide](aseprite-extension/README.md).

## Testing and development

The current checks cover five existing Rust tests, 12 Aseprite settings checks,
11 native integration checks, and a swamp-artwork exercise using the real engine.
The GUI test opened a new transparent sprite without changing the source.

The [swamp test fixture](test_img/README.md) includes a 640 x 640 image viewed at
30 degrees and a script that generates 64 x 64 comparison images. Those reductions
are separate test helpers; they do not imply that extension sizing is finished.

- [Build, local installation, and repeatable tests](docs/DEVELOPMENT.md)
- [Extension architecture, platform layout, presets, and verification results](docs/ASEPRITE_EXTENSION.md)
- [Preserved upstream README: standalone CLI and WASM](docs/upstream/README.md)

Next implementation checkpoints are Aseprite output sizing and the optional hex
mask, followed by reproducible Windows packaging and full installation QA.
Live previews, frame batches, automatic updates, and other platforms are outside
the current first-release scope.

## Credits and license

**Sprite Fusion Pixel Snapper's engine is by Hugo Duprez.** Its source remains
in [`src/`](src/), with the unchanged upstream [MIT license](LICENSE) and
`Copyright (c) 2025 Hugo Duprez` notice. The upstream engine is version `1.0.0`,
based on commit `ae20461f60fb39e75d15f184bab1ebec1219511c`.

**KoalaNalle's additions in this fork** are the Aseprite frontend, presets,
integration tests, test artwork, and extension documentation. These additions
use the [MIT extension license](LICENSE-EXTENSION). They do not claim authorship
of the upstream snapping algorithm. Extension and engine versions are separate.

See [third-party notices](THIRD_PARTY_NOTICES.md) for attribution and distribution
notes. Preserve the upstream license and copyright notice when distributing the
engine or an extension package that bundles it.
