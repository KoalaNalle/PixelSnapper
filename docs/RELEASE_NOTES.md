# Pixel Snapper for Aseprite 0.1.0

The first packaged Windows x64 release brings Sprite Fusion Pixel Snapper into Aseprite. Process the active frame and get a new editable sprite while keeping the source untouched.

## Included

- Generic / Detected Grid and Custom presets, with saved settings.
- Auto/Manual pixel-size detection and Auto/current/custom RGB palettes.
- Native, Exact, Fit + Pad and Crop output sizing with nearest-neighbor scaling.
- Transparency preservation, optional RGB background compositing, and an optional crisp pointy-top hex mask.
- A bundled Windows x64 Rust executable; no Rust, Python, downloads or separate Visual C++ runtime installation needed on the user's machine.
- Validation, exit diagnostics, temporary-file cleanup, licenses, dependency notices and source/binary build metadata.

Scaleweave presets remain available in source/development packages and are excluded from this shipping archive. The optional hex control remains available to all users.

## Install

Download **PixelSnapper-Aseprite-0.1.0.aseprite-extension** below. In Aseprite choose **Edit > Preferences > Extensions > Add Extension**, select the file, then save open work and restart. Open an image and choose **Sprite > Pixel Snapper...**. Allow temporary-file and external-program access when Aseprite asks.

The matching `.sha256` file verifies the package download. GitHub's Source code downloads contain the repository rather than the ready-to-install binary package.

If upgrading an early manually copied development version reports missing `__info.json`, follow the [migration instructions](https://github.com/KoalaNalle/PixelSnapper/blob/v0.1.0/docs/USER_GUIDE.md#troubleshooting) to back it up, install normally and restore `__pref.lua`.

## Verification and limits

Tested with Aseprite **1.3.18.5-x64** on Windows. Automated verification includes 5 existing Rust tests, 14 settings checks, 16 output/pixel checks, 13 native integration checks and an extracted-package end-to-end run. [QA record](https://github.com/KoalaNalle/PixelSnapper/blob/v0.1.0/docs/QA.md)

V1 handles one composited active frame and New Sprite output. Processing is synchronous, without live preview or cancellation once processing starts. macOS/Linux and Windows ARM64/x86 are unsupported. Exact sizing can alter aspect ratio. Fit uses full image bounds, including transparent margins. Unusual executable/temporary paths containing `%`, `!` or quotes are rejected; spaces work. See the [user guide](https://github.com/KoalaNalle/PixelSnapper/blob/v0.1.0/docs/USER_GUIDE.md) for details.

## Attribution

The snapping and quantization engine is **Sprite Fusion Pixel Snapper by Hugo Duprez**, retained unchanged at engine version **1.0.0** with its original MIT copyright/license. The Aseprite frontend and output/packaging work are maintained by **KoalaNalle** under MIT terms. The archive includes both license texts, third-party notices, dependency licenses and `BUILD-INFO.json` identifying the exact bundled revisions and binary.
