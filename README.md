# Pixel Snapper for Aseprite

Turn inconsistent pixel art into a new editable sprite with **Sprite > Pixel Snapper...**. Pixel Snapper renders the active frame, runs the bundled native engine, and opens the result without changing your original document.

This fork maintains the **Aseprite frontend** for [Sprite Fusion Pixel Snapper](https://github.com/Hugo-Dz/spritefusion-pixel-snapper), the Rust snapping and palette-quantization engine by **Hugo Duprez**. The original source, CLI, WASM support, tests, Git history, and copyright notices remain available.

## Install

**Version 0.1.0 · Windows x64 · Tested with Aseprite 1.3.18.5-x64**

1. Download the `.aseprite-extension` asset from [GitHub Releases](https://github.com/KoalaNalle/PixelSnapper/releases). GitHub's Source code ZIP is not the installable package.
2. In Aseprite, choose **Edit > Preferences > Extensions > Add Extension** and select the file.
3. Save open work and restart Aseprite.
4. Open an image and choose **Sprite > Pixel Snapper...**.

The native executable is included. End users do not need Rust, Python, or a separate Visual C++ runtime installation. Processing is local, with no network access or downloads. Aseprite may request permission to access temporary files and execute the bundled program. See the [user guide](docs/USER_GUIDE.md) for permissions and troubleshooting, including migration from an earlier manually copied development installation.

## Features

- **Auto or Manual pixel size**, using the existing engine's grid detection.
- **Auto, Current Aseprite Palette, or Custom HEX Palette**, with strict RGB validation.
- **Native, Exact, Fit + Pad, or Crop** output sizing. Scaling uses nearest-neighbor.
- **Preserve Alpha**, or flatten onto a selectable RGB background (white by default).
- Optional **pointy-top hex mask**, applied last with transparent edges and no outline or smoothing.
- **Generic / Detected Grid** and **Custom** presets, with remembered settings and customization tracking.
- A new unsaved RGB/RGBA sprite with one editable layer and frame. The source stays untouched.

Generic starts with 16 colors, Auto pixel size/palette, Native output, transparency preserved, and no mask. Custom keeps your current controls. Colors controls the engine's initial quantization even with a fixed palette. Manual pixel size guides grid detection; it does not promise exact dimensions.

| Sizing | Result |
| --- | --- |
| Native | Keep the engine's snapped dimensions. |
| Exact | Resize directly to the requested dimensions; may alter aspect ratio. |
| Fit + Pad | Fit and center within the requested canvas, preserving aspect ratio within whole-pixel rounding. |
| Crop | Center at the existing scale; trim excess and pad smaller dimensions. |

Output sizing, background compositing, and masking happen **after Rust snapping** in Aseprite. They do not change the snapping algorithm. Target dimensions remain editable; 64 x 64 is never imposed globally.

Shipping packages contain **Generic and Custom only**. Optional Scaleweave Terrain 64 and Feature 64 presets remain in the source and development packages. Terrain uses Fit + Pad at 64 x 64 with a hex mask; Feature uses the same size without a mask. Both use 32 colors and preserve transparency. [Preset development](aseprite-extension/README.md)

## Build and verification

With Rust/MSVC, Visual Studio C++ build tools, and a Windows SDK installed:

```powershell
./scripts/build-extension.ps1
./scripts/smoke-test.ps1 -AsepritePath 'C:\path\to\Aseprite.exe'
```

The build produces `dist/PixelSnapper-Aseprite-0.1.0.aseprite-extension` and a SHA-256 file. The package includes the Windows x64 engine, licenses and dependency notices, plus `BUILD-INFO.json` identifying the exact source and binary. Generated files are gitignored.

Verification covers 5 existing Rust tests, 14 settings checks, 16 pixel-level output checks, 13 native integration checks, and an extracted-package end-to-end test. The [swamp fixture](test_img/README.md) exercises a transparent 640 x 640 image and crisp 64 x 64 output. See [QA results and manual checklist](docs/QA.md) for actual GUI coverage and remaining verification limits.

- [User guide](docs/USER_GUIDE.md)
- [Build, development packages, and tests](docs/DEVELOPMENT.md)
- [Architecture and adding presets/platforms](docs/ASEPRITE_EXTENSION.md)
- [Release notes](docs/RELEASE_NOTES.md)
- [Preserved upstream README: standalone CLI and WASM](docs/upstream/README.md)

V1 processes a single composited active frame synchronously. New Layer, animation/batch workflows, live preview, and macOS/Linux binaries are not included. Large inputs can take time and memory; cancellation after processing starts is not available.

## Credits and license

**Sprite Fusion Pixel Snapper's engine is by Hugo Duprez.** Its source remains in [`src/`](src/), with the unchanged [MIT license](LICENSE) and `Copyright (c) 2025 Hugo Duprez` notice. The engine remains version **1.0.0**, from upstream baseline `ae20461f60fb39e75d15f184bab1ebec1219511c`.

**KoalaNalle's additions** are the Aseprite frontend, output processing, presets, packaging, integration tests, fixture artwork, and extension documentation. These use the [MIT extension license](LICENSE-EXTENSION); they do not claim authorship of the upstream algorithm. Extension and engine versions are separate.

[Third-party notices](THIRD_PARTY_NOTICES.md) identify the retained upstream work and bundled dependencies. Keep their license and copyright notices with distributed copies.
