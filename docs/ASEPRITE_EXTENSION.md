# Aseprite extension architecture

[Project overview](../README.md) · [Controls](../aseprite-extension/README.md) ·
[Development setup](DEVELOPMENT.md) · [Attribution](../THIRD_PARTY_NOTICES.md)

This document covers the frontend maintained in this fork. The authoritative
Rust engine remains in `src/`; its original CLI/WASM documentation is preserved
in the [upstream README](upstream/README.md). Reframing the repository around
Aseprite does not change the engine, its version, or its copyright notices.

## Checkpoint status

Implemented: command registration, modal settings dialog, built-in presets,
customization tracking, input validation, persistent settings, native invocation,
rendered active-frame export, palette extraction, and an unsaved new output sprite.

Pending: output sizing, hex mask, alpha removal, packaging, and full release QA.
The `0.1.0-dev.2` development build processes Native output with alpha preserved
and no mask. Other output settings are rejected with a checkpoint explanation
before any image export. Preset definitions are unchanged.

## Processing architecture

```text
Aseprite Lua UI                 implemented
      |
temporary rendered-frame PNG   implemented
      |
Rust Pixel Snapper CLI          existing, integration tested
      |
snapped PNG
      |
Aseprite output sizing/mask     pending
      |
new editable sprite            implemented (Native dimensions)
```

`pixel-snapper.lua` loads local modules using `plugin.path` and registers
`PixelSnapper` in the verified `sprite_size` menu group. Its enable callback
requires an active sprite and available UI. The modal dialog keeps its source
sprite stable while the user edits settings.

`lib/dialog.lua` builds controls from the schema in `lib/settings.lua`.
Settings validation and persistence have no dependency on the Rust process.
`plugin.preferences.last_preset` is a stable preset ID;
`last_settings` stores a separate table of primitive settings. `settings_version`
allows future preference migrations. Unknown/invalid stored fields fall back
individually to defaults. A successful Snap saves preferences; Cancel and failures
make no preference writes. The dialog captures the source frame when opened.

`lib/processing.lua` orchestrates validation, an independent RGBA
`Image:drawSprite()` render, PNG export, native processing, PNG loading, and a
new RGB sprite. It never flattens or writes into the source sprite. The new sprite
has one editable layer, one frame, the source color-space assignment, exact loaded
RGBA pixels, and a generated title without an associated file on disk.

`lib/palette.lua` reads the palette effective at the captured frame. Transparent
entries are omitted; the indexed transparency index is omitted for sprites
without a background layer. Remaining entries supply RGB only, are deduplicated,
and pass the same 256-color validation as custom HEX text.

`lib/runner.lua` owns platform lookup, unique temporary workspaces, command
construction, synchronous execution, diagnostics, and cleanup. Each run uses
timestamp, sprite ID, counter, and two random numeric suffixes under
`app.fs.tempPath/aseprite-pixelsnapper/`. Only that run's three known files and
empty directory are removed. Process errors are captured before log cleanup;
cleanup failures are reported. A crash may leave files for manual cleanup.

The actual CLI arguments are:

```text
spritefusion-pixel-snapper.exe <input.png> <snapped.png> <color_count>
                             [--pixel-size <positive integer>]
                             [--palette <six-digit-RGB,...>]
```

Auto pixel size omits its flag. Auto palette omits its flag. Color count remains
present for every palette mode because the core quantizes before palette mapping.
No output-size, alpha, mask, or invented sampling argument is passed.

On Windows, paths are quoted and numeric/palette arguments are validated again
at the command boundary. `%`, `!`, double quotes, and control characters in
executable/temporary paths are rejected because shell expansion can alter them.
Spaces, `&`, and parentheses were tested in both executable and temporary paths.
Source artwork paths are never passed to the shell. Commands over 8000 bytes are
rejected before execution. The process status, nonempty output file, and decoded
RGBA image must all succeed before creating a document.

Aseprite's ordinary script permission prompt controls external execution and
file access. The extension neither changes nor bypasses these permissions.
The process runs synchronously; no live preview or mid-process cancellation is
implemented. No network access, Python, or end-user Rust installation is needed.

## Presets

Presets are UI/output configurations, not alternative snapping algorithms.
`lib/presets.lua` owns the defaults and data table. Its public accessors return
copies, so callers cannot overwrite the definitions. Custom keeps current values.

Add a built-in by adding an entry to `definitions`:

```lua
{
  id = "my-preset", -- stable, unique preference key
  label = "My Preset", -- unique dropdown label
  description = "Purpose of this preset.",
  values = { color_count = 24, sizing_mode = "Fit + Pad", width = 96, height = 96 },
}
```

Any omitted values inherit the Generic defaults. No UI branch is required.
The 64 x 64 defaults belong to frontend preset data, not the Rust engine.

## Native binaries and release follow-up

Manual builds and local installation are described in [DEVELOPMENT.md](DEVELOPMENT.md).
Packages must carry the upstream `LICENSE`, the fork's `LICENSE-EXTENSION`, and
`THIRD_PARTY_NOTICES.md`, alongside any required dependency notices. These notices
identify the upstream engine separately from the frontend additions.

The binary directory scheme is:

```text
bin/windows-x64/spritefusion-pixel-snapper.exe
bin/linux-x64/spritefusion-pixel-snapper
bin/macos-x64/spritefusion-pixel-snapper
bin/macos-arm64/spritefusion-pixel-snapper
```

Windows x64 is implemented. The runner resolves paths from `plugin.path` and
the documented `app.os` platform/architecture flags. Adding a platform will
require its compiled binary and a tested invocation/quoting implementation.
There will be no runtime downloads.

Baseline Rust build/tests passed on Windows x64 with Rust 1.98.1: five existing
tests, CLI help/version, transparent PNG processing, custom palettes, manual
pixel size, error exit codes, and paths containing spaces. The default MSVC
executable imports `VCRUNTIME140.dll`; packaging must address this dependency.
Cargo also reports a non-blocking library/CLI PDB filename collision.
The engine version and upstream license remain unchanged.

## Settings checkpoint verification results

Verified with Aseprite **1.3.18.5-x64** on Windows. The development extension was
copied directly into the local Aseprite extensions directory with the unchanged
upstream `LICENSE`. Installation from an archive has not been tested yet.

All **12 settings regression checks passed** in Aseprite's own Lua interpreter
using `tests/aseprite-settings.lua`. These cover preset copy isolation, Custom
behavior, customization tracking, preference restoration and invalid-value
fallbacks, numeric validation, strict HEX validation and deduplication, palette
limits, input/output dimension validation, and Lua syntax.

Manual checks passed in the preceding settings-only checkpoint:

- The command is disabled without a sprite and opens from the Sprite menu with
  a sprite. All controls fit within the tested desktop window.
- The dropdown contains all four presets. Terrain loads 32 colors, Auto pixel
  size/palette, Fit + Pad at 64 x 64, alpha preservation, and the hex mask.
  Feature restores its corresponding defaults with the hex mask off.
- Changing a control marks the built-in customized. Selecting another built-in
  restores its defaults.
- Manual pixel size and Custom HEX Palette enable their corresponding fields.
  An empty custom palette produces a useful validation alert and keeps the
  settings dialog open.
- Save Settings restores the selected Feature preset and its values on reopening
  the dialog and after quitting and restarting Aseprite.
- Enabling the mask and then cancelling does not overwrite the saved mask-off
  value; this was confirmed in persisted preferences and after restart.
- The independent blank source sprite remains unchanged; no output document or
  image processing is created by this checkpoint.

Numeric boundary cases and Custom value retention were checked by the automated
suite, not exhaustively through GUI entry.

## Native processing checkpoint verification results

The unchanged Rust release build passed. The 12 settings checks still pass, and
all **11 native integration checks** passed in Aseprite 1.3.18.5-x64 with the real
Rust executable. Fixtures are generated by `tests/aseprite-processing.lua`.

- RGBA active-frame composition respects visible/hidden layers and cel offsets.
- Auto and Manual pixel size both run. This fixture produced 63 x 63 with Auto
  and 9 x 9 with Manual 8; these are observations, not promised output sizes.
- Auto, Current Aseprite Palette, and Custom HEX Palette run through the CLI.
  Custom/current output RGB values belong to the requested palette.
- Alpha 0, 128, and 255 survive the RGBA workflow. Indexed and grayscale input
  render correctly to RGBA and preserve transparent regions.
- Source pixels, image IDs/versions, frame/layer counts, filename, dirty state,
  and undo-step count are unchanged. Results are new, unsaved, editable RGB
  documents with the expected title and one layer/frame.
- Executable and temporary paths containing spaces, ampersands, and parentheses
  work. Unsafe command text is rejected.
- Unsupported platforms and missing binaries produce explicit errors.
- A corrupt PNG produces native exit code 1. Simulated successful execution with
  no output and failure with an output file both fail safely. No bogus document
  is opened, and handled success/failure runs leave no temporary run directories.

The last failure cases use a scoped test replacement of `os.execute`; successful
image-processing cases invoke the real engine. Numeric/palette validation errors
and pending output settings are also rejected without modifying the source.

The updated development extension and native binary were copied into the local
Aseprite extension directory, retaining preferences and the upstream license.
Installed source/binary files were checked against the working tree/build.
After restarting Aseprite, the updated Snap button opens normally. Pending output
settings show a readable, multi-line validation message and leave the source
unchanged. Selecting Generic restores Native settings and reaches the ordinary
Aseprite permission prompt for writing the temporary directory.

The initial GUI test paused at that prompt. The following swamp-artwork
checkpoint completed GUI processing after manual permission approval.
GUI permission-denial behavior and archive installation remain unverified.

## Swamp artwork checkpoint

A reproducible 640 x 640 transparent swamp hex tile was added under `test_img/`,
using a 30-degree camera elevation above the terrain plane. Aseprite created
a direct 64 x 64 nearest-neighbor reduction and exercised the real extension
processing module with Auto/16 colors and Manual 10/32 colors. Native results
were 126 x 122 and 67 x 68, respectively. Separate fixture helpers fitted those
results into 64 x 64 transparent canvases for visual comparison; extension output
sizing and masking remain pending.

The batch test passed: source pixels/dirty state/undo count were unchanged,
results were new unsaved sprites, cleanup reported no failures, and all five
output images preserved transparency with no partially transparent boundary
pixels. The direct 64 x 64 image matched the Canvas preview pixel for pixel.
The original input PNG's SHA-256 remained unchanged.

The installed extension's menu and Generic dialog were verified with the swamp
image in the GUI. After the user approved Aseprite's permissions manually, Snap
opened a new unsaved `swamp-hex-30deg-640-snapped` sprite at 126 x 122 with one
editable Snapped layer. Inspection at 400% zoom confirmed crisp pixels and a
transparent exterior. Switching to the original showed its unchanged 640 x 640
dimensions and no modified-document marker. The new result was left open for
review. See [the fixture notes](../test_img/README.md) for exact files, repeat
instructions, and the distinction between native and resized results.

## API references

Implementation was checked against the official Aseprite API documentation:
[Image](https://github.com/aseprite/api/blob/main/api/image.md),
[Sprite](https://github.com/aseprite/api/blob/main/api/sprite.md),
[Palette](https://github.com/aseprite/api/blob/main/api/palette.md),
[filesystem](https://github.com/aseprite/api/blob/main/api/app_fs.md), and
[platform flags](https://github.com/aseprite/api/blob/main/api/app_os.md).

The complete release checklist will be added with output processing and
packaging; archive installation and Scaleweave output are not verified yet.
