# Developing Pixel Snapper for Aseprite

[Overview](../README.md) · [User guide](USER_GUIDE.md) · [Architecture](ASEPRITE_EXTENSION.md) · [QA](QA.md)

The frontend wraps the retained Rust library/CLI. Do not move snapping or palette quantization into Lua. Standalone CLI and WASM instructions remain in the [upstream README](upstream/README.md).

## Windows prerequisites

- Rust with the `x86_64-pc-windows-msvc` target (verified with Rust 1.98.1).
- Visual Studio C++ build tools and a Windows SDK, including `dumpbin`.
- Aseprite for application tests (verified with 1.3.18.5-x64).

These are developer requirements. The packaged extension requires only Aseprite on Windows x64.

## Build a package

Run from the repository root in PowerShell:

```powershell
./scripts/build-extension.ps1
```

The script builds the locked Rust release binary for Windows x64 with the C runtime linked statically. It checks the PE architecture and imported DLLs, copies Lua sources and license/notice files into a clean directory under `dist/`, and creates a ZIP with `package.json` at its root. The ZIP uses the `.aseprite-extension` suffix. A SHA-256 sidecar and bundled `BUILD-INFO.json` record the artifact and its source.

Default packages contain Generic and Custom presets. For optional Scaleweave development presets:

```powershell
./scripts/build-extension.ps1 -Development
```

This produces a separate `-Development.aseprite-extension` archive and includes `lib/presets-development.lua`. Install either archive through Aseprite's extension preferences and restart. Both profiles share the extension ID and preferences; installing one updates the other. Switching to shipping falls back from a removed preset ID to Generic while retaining valid saved control values, marked customized.

Use archive installation for local development too. A manually copied extension lacks Aseprite's `__info.json` installer record and cannot be updated normally. See the migration instructions in the [user guide](USER_GUIDE.md#troubleshooting). Preserve `__pref.lua`; never fabricate installer metadata.

## Automated checks

```powershell
./scripts/smoke-test.ps1 -AsepritePath 'C:\path\to\Aseprite.exe'
```

The script runs the 5 existing Rust tests, builds the shipping package, checks CLI help and a small transparent PNG fixture, inspects/extracts the archive, checks licenses and binary hashes, and runs Aseprite's own Lua interpreter:

| Suite | Coverage |
| --- | --- |
| `tests/aseprite-settings.lua` | 14 checks: validation, palettes, defaults, preferences, background RGB, shipping fallback. |
| `tests/aseprite-output.lua` | 16 checks: nearest-neighbor mapping, centering, clipping, exact RGBA, background alpha math, symmetric hard hex edges. |
| `tests/aseprite-processing.lua` | 13 checks: real CLI, all palette/sizing modes, RGBA/indexed/grayscale, development presets, source preservation, error handling and cleanup. |
| `tests/aseprite-package.lua` | Extracted shipping modules and bundled executable, preset exclusion, command registration, a new transparent 64 x 64 result. |

The package is tested from a path containing spaces. Successful processing cases invoke the real Rust engine; selected failure cases use scoped replacements to simulate exit/output failures. Require final `*_OK` markers as well as process completion because Aseprite can return zero after a Lua error. Logs are in `dist/smoke-test/`.

Omit `-AsepritePath` to run only Rust/CLI/archive checks; the script explicitly reports application tests skipped. Do not describe that as full QA.

For the existing artwork exercise, use the staged binary and modules:

```powershell
& 'C:\path\to\Aseprite.exe' --batch --script-param 'plugin-root=C:\path\to\PixelSnapper\dist\stage-shipping' --script test_img/run-aseprite.lua | Out-Host
```

Piping a direct Aseprite invocation to `Out-Host` makes PowerShell wait for this GUI executable. The smoke script instead waits on the specific root process with a timeout and checks log markers. Optional artwork-generation tools are explained in [fixture notes](../test_img/README.md); they are not runtime dependencies.

## Release procedure

1. Finish feature and manual QA; update the manifest, user guide, QA record, and release notes. Keep the Rust crate version independent.
2. Review and commit the source. Do not commit generated `target/`, `dist/`, binaries, or temporary images.
3. Run `./scripts/smoke-test.ps1 -RequireClean -AsepritePath 'C:\path\to\Aseprite.exe'`. This fails on uncommitted changes and records the exact commit in the package.
4. Verify installation/update and the shipping preset list. If source changes, commit and rebuild before publishing.
5. With the repository owner's release authorization, tag that commit, upload the tested extension archive and its checksum to GitHub Releases, verify the uploaded assets, and publish the release notes. Do not replace existing release assets silently.

Build metadata contains the frontend commit, upstream baseline, last commit affecting Rust/Cargo, source-tree object, engine version, Rust toolchain, static-runtime setting, imported system DLLs, and binary SHA-256. Dependency notices come from the locked native Cargo graph; Rust's shipped copyright files are included too.

The existing Cargo library/CLI PDB-name collision warning is non-blocking. No Rust algorithm, dependency, or version changes were needed for this extension.
