-- SPDX-License-Identifier: MIT
-- Development-only presets. This file is excluded from shipping packages.
return {
  {
    id = "scaleweave-terrain-64", label = "Scaleweave Terrain 64",
    description = "Centered terrain with a transparent pointy-top hex mask.",
    values = { color_count = 32, sizing_mode = "Fit + Pad", hex_mask = true },
  },
  {
    id = "scaleweave-feature-64", label = "Scaleweave Feature 64",
    description = "Centered overlay art with transparency and no hex mask.",
    values = { color_count = 32, sizing_mode = "Fit + Pad" },
  },
}
