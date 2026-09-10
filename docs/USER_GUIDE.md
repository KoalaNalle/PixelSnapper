# Pixel Snapper for Aseprite

Pixel Snapper processes the active frame using Sprite Fusion Pixel Snapper's Rust
engine and opens a new editable sprite. Your source document stays unchanged.
This package supports **Windows x64**, tested with **Aseprite 1.3.18.5-x64**.

## Install

In Aseprite, choose **Edit > Preferences > Extensions > Add Extension**, select
the `.aseprite-extension` file, and restart Aseprite. Save open work before
restarting. The package includes the native executable; Rust is not required.
No runtime network access, Python, downloads, or external services are used.

## Process an image

1. Open an image and select the desired frame.
2. Choose **Sprite > Pixel Snapper...**.
3. Start with **Generic / Detected Grid**, or choose **Custom** to keep your
   current controls while adjusting them.
4. Choose the snapping and output settings, then click **Snap**.
5. Allow Aseprite's temporary-file access and external-program permission prompts.
6. Edit the new `-snapped` sprite and save it where you choose.

The visible layers of the active frame are rendered together into a temporary
RGBA PNG. Other frames are not processed. Indexed/grayscale input is supported.
The command is disabled without an active sprite. Successful processing remembers
your settings; Cancel leaves the source and saved settings unchanged.

## Snapping

- **Colors:** the engine's initial quantization count. It remains relevant with
  fixed palettes because palette mapping occurs after quantization/snapping.
- **Pixel Size:** Auto lets the engine detect the grid. Manual accepts a positive
  integer no greater than half the smaller input dimension. It guides detection;
  it does not guarantee specific output dimensions.
- **Palette:** Auto, Current Aseprite Palette, or Custom HEX Palette. Custom input
  accepts comma-separated six-digit RGB colors, for example `0d2b45,203c56,ffecd6`.
  Do not include `#` or alpha. Transparent palette entries are omitted and duplicate
  RGB values are removed. Partial-alpha entries contribute RGB only.

## Output

Output processing takes place in Aseprite after the native engine finishes.

| Sizing | Behavior |
| --- | --- |
| Native | Keep the snapped dimensions exactly. |
| Exact | Resize to width x height using nearest-neighbor; this can change aspect ratio. |
| Fit + Pad | Scale up or down to fit, preserve aspect ratio within whole-pixel rounding, and center on the requested canvas. |
| Crop | Keep the existing scale; center, trim excess, and pad dimensions that are smaller than the target. |

Width and height are editable from 1 to 10000. Fit uses the complete snapped
image bounds, including existing transparent margins. All resizing is crisp,
with no smoothing. Half-pixel centering ties place the image toward the top-left.

**Preserve Alpha** keeps the snapped transparency and transparent padding. Turn
it off to composite onto **Background RGB** (default white). The background uses
RGB only, regardless of any alpha shown in Aseprite's color picker.

**Pointy Hex Mask** makes pixels outside a normalized pointy-top hex transparent.
It runs last, even with Preserve Alpha off. It adds no outline or antialiasing.
The mask uses your final canvas dimensions and is optional.

**New Sprite** is the supported destination. The new RGB/RGBA document has one
editable layer and frame and remains unsaved. Processing is synchronous; there
is no live preview or cancellation after native processing starts.
The result's palette panel is not automatically populated from its colors;
the image retains its exact RGB pixels for ordinary editing and eyedropper use.

## Troubleshooting

If updating an early manually copied development installation reports a missing
`__info.json`, save your work and close Aseprite. Back up the existing
`extensions/pixel-snapper` folder outside Aseprite's extension directory, then
install the archive normally. To retain settings, close Aseprite again, copy
only the backed-up `__pref.lua` into the newly installed folder, and restart.
Keep the installer-generated `__info.json`; do not replace or fabricate it.
Normal Windows configuration lives under `%APPDATA%/Aseprite`; portable
installations can differ.

The extension reports invalid fields before execution, checks the process status
and output PNG, and cleans up temporary files after successful and handled failed
runs. A crash can leave files under the system temporary directory's
`aseprite-pixelsnapper` folder. Cleanup failures are reported.

If the executable is missing, reinstall the complete extension package. macOS,
Linux, and Windows x86/ARM64 are not currently supported. Executable and temporary
paths containing spaces, ampersands, and parentheses work. Paths containing `%`,
`!`, quotes, or control characters are rejected before execution. Artwork
filenames are never inserted into a shell command. Large images or color counts
can take substantial time and memory.

## Credits and license

The snapping and quantization engine is **Sprite Fusion Pixel Snapper by Hugo
Duprez**, retained under its original MIT license and copyright notice. The
Aseprite frontend is maintained by **KoalaNalle** under MIT terms. See the bundled
`LICENSE`, `LICENSE-EXTENSION`, `THIRD_PARTY_NOTICES.md`, and `licenses/` directory.
`BUILD-INFO.json` identifies the engine and extension versions, source revision,
and native binary included in this package.

Project and releases: https://github.com/KoalaNalle/PixelSnapper
Upstream engine: https://github.com/Hugo-Dz/spritefusion-pixel-snapper
