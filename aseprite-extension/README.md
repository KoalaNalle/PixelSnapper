# Pixel Snapper extension source

[User guide](../docs/USER_GUIDE.md) · [Build and package](../docs/DEVELOPMENT.md) · [Architecture](../docs/ASEPRITE_EXTENSION.md) · [QA](../docs/QA.md)

This directory contains the Aseprite frontend for **Sprite Fusion Pixel Snapper by Hugo Duprez**. The authoritative snapping and palette quantization remain in the Rust engine. Extension version **0.1.0** is independent of engine version **1.0.0**.

## Presets in source and development packages

| Preset | Colors | Output | Alpha | Hex mask |
| --- | --- | --- | --- | --- |
| Generic / Detected Grid | 16 | Native | Preserve | Off |
| Scaleweave Terrain 64 | 32 | Fit + Pad, 64 x 64 | Preserve | On |
| Scaleweave Feature 64 | 32 | Fit + Pad, 64 x 64 | Preserve | Off |
| Custom | Keep current controls | Editable | Editable | Editable |

All built-ins start with Auto pixel size/palette and New Sprite output. Dimensions remain editable. Definitions are copied when selected; editing controls never overwrites a preset. Successful processing remembers settings; Cancel and failures do not save them.

**Shipping packages contain Generic and Custom only.** Scaleweave definitions live in `lib/presets-development.lua`; the default packaging script excludes that file. Build with `-Development` to include it. Presets configure the same frontend and engine, without alternate algorithms or global 64 x 64 assumptions. The generic hex-mask control remains available in shipping packages.

Install the generated archive rather than copying this source directory manually. The package README is built from `docs/USER_GUIDE.md`, so end-user instructions describe the shipping profile.

## Attribution

The Lua frontend, presets, output processing, and integration are maintained by **KoalaNalle** under [LICENSE-EXTENSION](../LICENSE-EXTENSION). The upstream engine retains the unchanged [MIT LICENSE](../LICENSE), including `Copyright (c) 2025 Hugo Duprez`. Both licenses and [third-party notices](../THIRD_PARTY_NOTICES.md) accompany packaged binaries. Original CLI/WASM documentation remains [available here](../docs/upstream/README.md).
