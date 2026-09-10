# Attribution and third-party notices

## Sprite Fusion Pixel Snapper

- Original project: [Hugo-Dz/spritefusion-pixel-snapper](https://github.com/Hugo-Dz/spritefusion-pixel-snapper)
- Author and upstream copyright holder: **Hugo Duprez**
- Copyright notice: **Copyright (c) 2025 Hugo Duprez**
- License: **MIT**, preserved verbatim in the repository's [LICENSE](LICENSE)
- Engine crate version: **1.0.0**
- Upstream baseline: [`ae20461f60fb39e75d15f184bab1ebec1219511c`](https://github.com/Hugo-Dz/spritefusion-pixel-snapper/commit/ae20461f60fb39e75d15f184bab1ebec1219511c)

The Rust library, native CLI, WASM support, snapping algorithm, and palette
quantization originate from this upstream project. The extension invokes that
engine; it does not replace it with a Lua implementation. The original source
and Git history are retained. Upstream illustrations remain in `static/`, and
the [archived upstream README](docs/upstream/README.md) preserves their context.
They are not presented as artwork or algorithms authored by this fork.

## Aseprite frontend and fork additions

The Lua frontend in `aseprite-extension/`, build/package scripts in `scripts/`, extension-specific tests in `tests/`,
the generated swamp fixture and its helpers in `test_img/`, and the extension
documentation are additions maintained by **KoalaNalle**. These additions use
the MIT terms in [LICENSE-EXTENSION](LICENSE-EXTENSION). That notice does not
replace Hugo Duprez's notice or apply a new authorship claim to upstream work.

The Aseprite application is a separate prerequisite and is not bundled here.

## Distribution contents

An extension distribution containing the native engine must carry the original
`LICENSE` alongside `LICENSE-EXTENSION` and this attribution file. This file
supplements the license texts; it does not replace them. Keep all existing
copyright and permission notices with the code to which they apply.

Rust dependencies are recorded in `Cargo.toml` and pinned in `Cargo.lock`;
their authors retain their own copyrights and licenses. The packaging script
copies the license and notice files supplied by the locked native dependency
graph into `licenses/<crate>-<version>/`, with a manifest in
`licenses/dependencies.json`. The 0.1.0 Windows build includes notices for 30
registry crates, plus the toolchain's Rust copyright files in `licenses/rust/`.
These original texts retain their respective authors' notices and terms.

The Windows executable is built with the C runtime linked statically. Its
imports are checked during packaging; no separate Visual C++ runtime installer
or DLL is shipped. `BUILD-INFO.json` records the toolchain, imports and binary
checksum. This attribution file supplements those notices without changing them.

Extension 0.1.0 bundles the unchanged 1.0.0 engine from the upstream baseline
above. Each package's `BUILD-INFO.json` records the frontend source commit,
engine source commit/tree, baseline revision, engine and extension versions.
Frontend output sizing, alpha handling and masking do not replace the upstream
snapping algorithm or change the engine version.
