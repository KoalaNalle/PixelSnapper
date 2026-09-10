# Aseprite extension architecture

[Overview](../README.md) · [User guide](USER_GUIDE.md) · [Development](DEVELOPMENT.md) · [QA](QA.md)

The authoritative Rust engine remains in `src/`. Its original CLI/WASM documentation is preserved in the [upstream README](upstream/README.md). Extension 0.1.0 requires no changes to the engine source, Cargo manifests, algorithm, or version.

## Processing

```text
Aseprite Lua UI
      |
temporary PNG of composited active frame
      |
Rust Pixel Snapper CLI
      |
native snapped PNG
      |
Aseprite output sizing
      |
optional RGB background compositing
      |
optional pointy-top hex mask
      |
new editable sprite
```

`pixel-snapper.lua` loads local modules through `plugin.path` and registers `PixelSnapper` in Aseprite's verified `sprite_size` menu group. The command requires UI and an active sprite. A modal dialog captures the source sprite/frame, preventing a source switch while editing settings.

| Module | Responsibility |
| --- | --- |
| `lib/dialog.lua` | Preset selection, schema-driven controls, enable states, summary, validation alerts and processing status. |
| `lib/settings.lua` | Supported values, strict validation, customization comparisons and primitive preference data. |
| `lib/presets.lua` | Generic/Custom definitions and optional development data loading. |
| `lib/palette.lua` | Read the palette effective at the captured frame, omit transparent entries, deduplicate RGB. |
| `lib/processing.lua` | Orchestrate export, native processing, output transforms and new-document creation. |
| `lib/runner.lua` | Platform lookup, unique workspaces, safe CLI construction, synchronous execution, diagnostics and cleanup. |
| `lib/output.lua` | Nearest-neighbor sizing, exact RGBA placement and optional background compositing. |
| `lib/geometry.lua` | Pixel-center polygon containment and hard transparent hex masking. |

The source frame is rendered with `Image:drawSprite()` into an independent RGBA image. Visible layers are composited without flattening the source. Indexed/grayscale sources become valid RGBA PNG input. Only after native success and PNG decoding does the extension create a new RGB sprite with one frame and layer, the source color-space assignment, final RGBA pixels, and an unsaved `-snapped` title. Tests verify source pixels, image versions, frames/layers, dirty state, filename and undo count remain unchanged.

## CLI boundary and temporary files

```text
spritefusion-pixel-snapper.exe <input.png> <snapped.png> <color_count>
                             [--pixel-size <positive integer>]
                             [--palette <six-digit-RGB,...>]
```

Auto pixel size omits its flag; Auto palette omits its flag. Color count remains present with every palette mode because the engine quantizes before palette mapping. Output size, alpha, background, and mask are exclusively frontend settings. No invented sampling modes are exposed.

Current palette mode uses the palette effective at the captured frame. Fully transparent entries are omitted, as is the indexed transparent index when there is no background layer. Remaining colors contribute RGB only. Custom/current palettes are deduplicated and limited to 256 RGB entries. Partial-alpha palette entries do not control image alpha.

Each workspace uses timestamp, sprite ID, an incrementing counter and two random numeric suffixes under `app.fs.tempPath/aseprite-pixelsnapper/`. Export, output and log filenames are controlled by the extension. Paths are quoted; numbers and HEX arguments are validated again at the command boundary. Windows `%`, `!`, quotes and control characters are rejected in executable/temporary paths because shell expansion can alter them. Spaces, ampersands and parentheses work. Source artwork paths are never passed to the shell. Commands over 8000 bytes are rejected.

The runner interprets the Lua process result and exit code, captures bounded diagnostics, checks for a nonempty PNG and lets Aseprite decode it before document creation. Success and handled failure clean up the three known files and then the empty run directory. Cleanup failures are reported; a crash may leave its directory behind. Aseprite retains control over file/process permission prompts. No permissions are bypassed and no network access is used. Processing is synchronous.

## Output sizing, alpha and geometry

- **Native** returns the snapped image unchanged.
- **Exact** copies and calls Aseprite's nearest-neighbor `Image:resize(width, height)` overload. This may change aspect ratio.
- **Fit + Pad** uses the smaller target/native axis ratio, rounds dimensions to whole pixels (at least one), resizes, and centers. Full bounds, including transparent margins, participate; no implicit trimming occurs.
- **Crop** centers without scaling. Each axis is independently clipped or padded.

Centering offsets use `floor((target - image) / 2)`, placing half-pixel ties toward the top-left. `Image(image, Rectangle(...))` copies the region and pads out-of-bounds pixels transparently, avoiding alpha blending and preserving exact RGBA values. Native and source images are not mutated.

When Preserve Alpha is off, the resized image is composited onto the validated six-digit Background RGB color, default white. Channels use rounded `(source * alpha + background * (255-alpha)) / 255` and output alpha 255. This intentionally changes partially transparent colors. Background preferences store RGB text, not a Color userdata object.

The optional mask runs last. For pixel centers `u=(x+0.5)/width`, `v=(y+0.5)/height`, the half-width is `2*v` above 25%, `0.5` through 75%, and `2*(1-v)` below. Pixels satisfying `abs(u-0.5) <= halfWidth` are retained; all others become fully transparent. This is the polygon `(50%,0%), (100%,25%), (100%,75%), (50%,100%), (0%,75%), (0%,25%)`. It scales to all target dimensions, is symmetric, adds no black border or antialiasing, and can leave transparent corners even when Preserve Alpha is off.

## Presets and preferences

Presets are configurations of the same UI and output stages, not alternate snapping algorithms. Public accessors return copies. Custom keeps existing controls. Add a normal built-in to the `builtins` data table in `lib/presets.lua`, before Custom:

```lua
{
  id = "my-preset", -- stable unique preference key
  label = "My Preset", -- unique dropdown label
  description = "Purpose of this preset.",
  values = { color_count = 24, sizing_mode = "Fit + Pad", width = 96, height = 96 },
}
```

Omitted fields inherit Generic defaults. No UI branch is needed. Development-only entries use the same structure in `lib/presets-development.lua`. `configure(plugin.path)` loads that file only when present. Default packaging physically excludes it, so shipping contains Generic and Custom only. Development packages retain Scaleweave Terrain/Feature with editable 64 x 64 defaults and optional masking.

`plugin.preferences.last_preset` stores the stable ID; `last_settings` stores separate primitive values and `settings_version` supports future migration. Successful Snap saves; Cancel/failure do not. Invalid stored fields fall back independently. If a saved Scaleweave ID is unavailable in shipping, the dialog selects Generic while retaining valid remembered controls and marking them customized. Built-in definitions never receive preference writes.

## Native binaries and adding a platform

```text
bin/windows-x64/spritefusion-pixel-snapper.exe
bin/linux-x64/spritefusion-pixel-snapper
bin/macos-x64/spritefusion-pixel-snapper
bin/macos-arm64/spritefusion-pixel-snapper
```

Only Windows x64 is implemented. Lookup uses `plugin.path` and documented `app.os` platform/architecture flags. Unsupported combinations return: `Pixel Snapper native binary is not available for this platform yet.` Missing Windows binaries receive an explicit reinstall message. Adding a platform requires the compiled binary, a tested platform launcher/quoting implementation, packaging and native QA. The directory layout needs no redesign and there are no runtime downloads.

Windows packaging builds with static CRT, checks the actual PE/imports, and includes upstream/extension MIT texts, attribution, locked Cargo dependency license files and Rust copyright notices. `BUILD-INFO.json` identifies the exact frontend and engine revisions, binary checksum and toolchain. See [development and release procedure](DEVELOPMENT.md) and [verification results](QA.md).

## Official API references

Implementation was checked against Aseprite's [Image](https://github.com/aseprite/api/blob/main/api/image.md), [Sprite](https://github.com/aseprite/api/blob/main/api/sprite.md), [Palette](https://github.com/aseprite/api/blob/main/api/palette.md), [filesystem](https://github.com/aseprite/api/blob/main/api/app_fs.md), [platform flags](https://github.com/aseprite/api/blob/main/api/app_os.md), and [Plugin](https://github.com/aseprite/api/blob/main/api/plugin.md) documentation. Runtime behavior is verified in Aseprite's own Lua interpreter.
