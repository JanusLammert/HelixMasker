# HelixMask — Cryo-EM Helical Density Map Masking Tool

A fully browser-based helical mask design tool for cryo-EM volumes. No server required — runs entirely in your browser. Open `Helix_Masker.html` directly; no installation needed.

---

## Overview

HelixMask lets you draw a 2D cross-section mask on a loaded MRC volume and extends it into a full 3D helical mask by applying the volume's helical symmetry (rise and twist per subunit). A cosine soft edge is applied via a separable Euclidean distance transform, and all heavy computation runs in a Web Worker so the interface stays responsive while editing.

---

## Features

### Volume loading
- Drop or browse a `.mrc` / `.mrcs` file directly in the browser
- Volume dimensions, pixel size, and box size are read from the MRC header and displayed in the sidebar

### Helix parameters
- Select the helix axis (X, Y, or Z)
- Set rise per subunit (Å) and twist per subunit (°)
- Set the soft edge width (Å) applied at the mask boundary

### Drawing tools
- **Brush**, **Eraser**, **Polygon**, and **Flood Fill** tools, each with a dedicated keyboard shortcut
- Adjustable brush size and mask overlay opacity
- Undo / redo with keyboard shortcuts
- Invert or clear the current mask with one click

### Auto-Mask
- Automatically segments the helix cross-section from the volume density using a density-percentile threshold
- Configurable dilation (in pixels) to grow the segmented region
- Optional "central region only" restriction and "fill interior holes" post-processing
- Live cyan preview overlay before committing — click Apply to merge into the mask, then refine manually with the brush tools

### Radial constraints
- Optionally restrict the mask to an annulus by specifying inner and outer radius (Å), applied as a ring mask

### Rotational symmetry
- Apply Cn rotational symmetry (C1–C4, or any custom order up to C36) to the 2D cross-section mask
- The mask is automatically symmetrized after each stroke, with dashed guide spokes showing the symmetry axes

### Slice navigation
- Switch between XY, XZ, and YZ cross-section views of the loaded volume
- Slice index slider and adjustable contrast range (low/high percentile) for display

### Symmetry preview
- Side view (along the helix axis) and three cross-sections (25%, 50%, 75%) of the resulting 3D mask, computed on a downsampled volume for responsiveness
- Live statistics: volume fraction, mask voxel count, rise in pixels, and edge width in pixels

### Export
- Generates the full-resolution 3D mask (helical symmetry applied + cosine soft edge) and downloads it as a standard MRC float32 file with a correct header

---

## Getting Started

1. Download `Helix_Masker.html` and open it in a browser
2. Drop your `.mrc` / `.mrcs` volume onto the upload zone
3. Set the helix axis, rise, and twist for your structure
4. Draw the 2D cross-section mask using the brush, polygon, or auto-mask tools, optionally applying Cn symmetry
5. Use **Update Preview** to inspect the resulting 3D mask, then **Generate & Download 3D Mask** to export

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `B` | Brush tool |
| `E` | Eraser tool |
| `P` | Polygon tool |
| `F` | Flood fill |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `[` / `]` | Smaller / larger brush |
| `Scroll` | Brush size |
| `Ctrl+Scroll` | Zoom |
| `Alt+drag` | Pan view |
| `Del` | Clear mask |
| `Esc` | Cancel polygon |

---

## Technical Notes

- All heavy computation (Euclidean distance transform, rotation, helical symmetry application) runs in a dedicated Web Worker, keeping the UI thread responsive during preview and export
- The Euclidean distance transform uses the separable Felzenszwalb–Huttenlocher algorithm (three 1D passes) for the cosine soft edge
- Preview computation runs on a downsampled copy of the volume (max 96 px per axis) for speed; export always uses the full-resolution volume
- MRC output follows the MRC2014 standard with a correct `MAP` identifier and machine stamp

---

## License

```
Copyright (C) 2026 Janus Lammert

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
```

Contact: j.lammert@fz-juelich.de
