# Aseprite extension architecture

## Checkpoint status

Implemented: command registration, modal settings dialog, built-in presets,
customization tracking, input validation, and persistent settings.

Pending: native invocation, rendered active-frame export, palette extraction,
output sizing, hex mask, new output sprite, packaging, and end-to-end QA.
The current development build saves settings only and cannot snap an image.

## Intended processing architecture

```text
Aseprite Lua UI                 implemented
      |
temporary rendered-frame PNG   pending
      |
Rust Pixel Snapper CLI          existing, baseline tested
      |
snapped PNG
      |
Aseprite output sizing/mask     pending
      |
new editable sprite            pending
```

`pixel-snapper.lua` loads local modules using `plugin.path` and registers
`PixelSnapper` in the verified `sprite_size` menu group. Its enable callback
requires an active sprite and available UI. The modal dialog keeps its source
sprite stable while the user edits settings.

`lib/dialog.lua` builds controls from the schema in `lib/settings.lua`.
Settings validation and persistence have no dependency on the Rust process.
There are no executable paths, process calls, or image modifications in this
checkpoint. `plugin.preferences.last_preset` is a stable preset ID;
`last_settings` stores a separate table of primitive settings. `settings_version`
allows future preference migrations. Unknown/invalid stored fields fall back
individually to defaults. Cancel makes no preference writes.

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

The planned installed directory scheme is:

```text
bin/windows-x64/spritefusion-pixel-snapper.exe
bin/linux-x64/spritefusion-pixel-snapper
bin/macos-x64/spritefusion-pixel-snapper
bin/macos-arm64/spritefusion-pixel-snapper
```

Windows x64 will be first. The runner will resolve paths from `plugin.path` and
the documented `app.os` platform/architecture flags. Adding a platform will
require its compiled binary and a tested invocation/quoting implementation.
There will be no runtime downloads.

Baseline Rust build/tests passed on Windows x64 with Rust 1.98.1: five existing
tests, CLI help/version, transparent PNG processing, custom palettes, manual
pixel size, error exit codes, and paths containing spaces. The default MSVC
executable imports `VCRUNTIME140.dll`; packaging must address this dependency.
Cargo also reports a non-blocking library/CLI PDB filename collision.
The engine version and upstream license remain unchanged.

## UI verification checklist

- Command disabled without a sprite; opens under Sprite with a sprite.
- Built-in preset selection updates all controls.
- Edits mark a built-in customized without changing its defaults.
- Custom keeps existing values; target dimensions remain editable.
- Manual size, HEX text, and target dimensions enable only when relevant.
- Invalid numeric values/palettes give useful messages; the dialog stays open.
- Save Settings survives reopening/restarting; Cancel discards changes.
- Source sprite remains unchanged.

The complete processing and installation checklist will be added with the
runner and packaging checkpoints; those features are not verified yet.
