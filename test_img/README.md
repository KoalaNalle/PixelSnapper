# Swamp hex tile test fixture

A deterministic 640 x 640 RGBA drawing of a swamp tile, viewed at a **30-degree
camera elevation above the terrain plane**. The transparent exterior surrounds
the terrain and trees. This is a projected hex tile with raised scenery, not a
flat pointy-top hex mask. The source drawing contains no antialiasing.

`swamp-tile.html` draws the fixture and displays a 64 x 64 nearest-neighbor
comparison. `render-fixture.cjs` exports that same drawing to PNG. These files
generate test artwork only; they do not implement Pixel Snapper's algorithm.

## Saved images and observed results

| File | Dimensions | Processing |
| --- | --- | --- |
| `input/swamp-hex-30deg-640.png` | 640 x 640 | Original fixture |
| `output/swamp-hex-30deg-64.png` | 64 x 64 | Aseprite nearest-neighbor reduction of the original |
| `output/swamp-snapped-auto-native.png` | 126 x 122 | Rust engine, Auto grid, 16 colors |
| `output/swamp-snapped-auto-64.png` | 64 x 64 | Native Auto result fitted/centered using nearest-neighbor |
| `output/swamp-snapped-manual10-native.png` | 67 x 68 | Rust engine, Manual pixel size 10, 32 colors |
| `output/swamp-snapped-manual10-64.png` | 64 x 64 | Native Manual result fitted/centered using nearest-neighbor |
| `output/swamp-comparison.png` | 960 x 355 | Enlarged direct/Auto/Manual comparison for review |

Native dimensions are observations from this fixture and build. Manual pixel
size guides the adaptive grid; it does not promise an exact output size. Auto
and Manual examples also use different color counts and are not a controlled
comparison of pixel-size modes alone.

The snapped 64 x 64 images now run through the extension's complete **Fit + Pad**
pipeline in `0.1.0`. The original dev.2 check used a separate sizing helper;
that duplicate implementation has been removed. Optional hex masking is verified
separately by the pixel-level output and full integration tests.
All image files have a transparent exterior; checkerboards appear only in the
comparison view. Generated outputs and logs are gitignored.

## Repeat the Aseprite test

From the repository root, after running `scripts/build-extension.ps1`, use the
absolute path to the staged shipping extension:

```powershell
& 'C:\path\to\Aseprite.exe' --batch --script-param 'plugin-root=C:\path\to\PixelSnapper\dist\stage-shipping' --script test_img/run-aseprite.lua | Out-Host
```

Adjust the Aseprite executable path for another installation. The checked-in
input PNG is sufficient; Node and Canvas are not needed to run this test.

`run-aseprite.lua` creates the five processed PNGs in the table and prints results.
It uses the actual extension processing module and Rust executable. It verifies
that source pixel bytes, dirty state, and undo count remain unchanged; results
are new unsaved documents; cleanup reports no failures; and every saved output
contains both visible pixels and transparency, with alpha restricted to 0/255.

Originally verified on Windows with **Aseprite 1.3.18.5-x64** and extension **0.1.0-dev.2**.
The batch test passed. The direct 64 x 64 PNG also matched the Canvas preview
pixel for pixel. The source PNG SHA-256 before and after testing was:

```text
F6D3344AAD89D40FF2B78058B1A61053E1BD1C62C9900BF1C452FB92EDA3B94E
```

In the dev.2 GUI check, the installed extension was opened through **Sprite > Pixel Snapper...** with
this source image. Its dialog correctly showed Generic, 16 colors, Auto grid,
Auto palette, Native output, alpha on, and mask off. Clicking Snap reached the
ordinary Aseprite temporary-directory write permission prompt. After the user
approved permissions manually, processing completed and opened a new unsaved
`swamp-hex-30deg-640-snapped` sprite at 126 x 122 with one editable Snapped layer.
Inspection at 400% zoom confirmed crisp pixels and a transparent exterior. The
original remained open at 640 x 640 without a modified-document marker. The
automated checks above verify source pixel/undo preservation beyond that visual
inspection. GUI permission-denial behavior has not been tested.

## Regenerate the drawing

With Node and `@napi-rs/canvas` available to Node's module resolver:

```powershell
node test_img/render-fixture.cjs
```

The verified generator used `@napi-rs/canvas` 0.1.100 from the local development
runtime. It overwrites the input fixture and creates a Canvas reference under
`target/`. Rerun the Aseprite command to refresh processed images. The optional
three-panel review PNG was assembled separately from those generated images.
These drawing tools are development conveniences, not extension dependencies.
