# HelixMask — Cryo-EM Helical Density Map Masking Tool

Interactive browser-based tool for creating 3D helical masks from RELION and cryoSPARC helical reconstructions.

## Features

- **MRC/MRCS file loading** — drag & drop or file picker
- **Drawing tools** — Brush, Eraser, Polygon (lasso), Flood Fill
- **Helical symmetry** — extend 2D cross-section mask to full 3D using rise & twist
- **Soft edge** — RELION-compatible cosine soft-edge masking
- **Live preview** — see symmetrized mask in side view + 3 cross-sections
- **Radial guide rings** — overlay rings at user-defined radii (Å)
- **Ring mask** — auto-fill between inner/outer radius in one click
- **Undo/Redo** — 30-step history
- **Invert & Clear** mask operations
- **Export** — full-resolution 3D MRC mask with correct pixel size header

---

## Option A — Double-click launcher (no terminal needed)

Just double-click the launcher for your platform. It will automatically create
the conda/mamba environment on first run and open your browser.

| Platform | File to double-click |
|----------|----------------------|
| **macOS** | `Launch_HelixMask_macOS.command` |
| **Windows** | `Launch_HelixMask_Windows.bat` |
| **Linux** | `Launch_HelixMask_Linux.sh` |

> **macOS note:** On first launch macOS may block the `.command` file.  
> Right-click → Open → Open to approve it once. After that, double-click works normally.

> **Linux note:** Right-click the `.sh` file → Properties → mark as executable,  
> then double-click and choose "Run in terminal".

The launchers search for `mamba`, `micromamba`, and `conda` automatically
(Mambaforge, Miniforge, Anaconda, Miniconda are all detected).

---

## Option B — mamba / conda (terminal)

```bash
# Create environment (once)
mamba env create -f environment.yml

# Activate and run
mamba activate helixmask
python app.py
```

Then open: **http://localhost:5173**

---

## Option C — pip (terminal)

```bash
pip install -r requirements.txt
python app.py
```

Required packages: `flask`, `mrcfile`, `numpy`, `scipy`, `Pillow`

## Usage

1. **Load volume** — drag your `.mrc` or `.mrcs` file onto the app
2. **Set helix parameters** — enter the helical rise (Å), twist (°), and helix axis (usually Z)
3. **Set soft edge** — typically 6–12 Å (RELION convention)
4. **Draw mask** — use brush or polygon to outline the helix cross-section on the XY slice
5. **Preview** — click "Update Preview" to see the 3D symmetrized mask
6. **Export** — click "Generate & Download 3D Mask" to save the `.mrc` file

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `B` | Brush tool |
| `E` | Eraser tool |
| `P` | Polygon tool (double-click to close) |
| `F` | Flood fill |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `[` / `]` | Decrease / increase brush size |
| `Scroll` | Zoom in/out |
| `Alt+drag` | Pan canvas |
| `Del` | Clear mask |
| `Esc` | Cancel polygon |

## Notes

- **Helix axis**: Set this to match the axis the helix runs along in your reconstruction. For standard RELION/cryoSPARC helical reconstructions, this is typically **Z**.
- **View axis**: This controls the cross-section shown for drawing. For helix along Z, use the **XY** cross-section view.
- **Rise and twist**: Match these exactly to your RELION/cryoSPARC reconstruction parameters.
- **Soft edge**: Use the same value you plan to use in RELION `relion_mask_create` or cryoSPARC.
- The exported mask has the same box dimensions and pixel size as the input volume.

## Output

The exported `helical_mask.mrc` is a float32 MRC file with values in [0, 1], compatible with:
- RELION `--solvent_mask` parameter
- cryoSPARC mask input
- EMAN2 mask operations

## LICENSE

HelixMasker allows for an easy creation of helical masks for Cryo-EM-Processing.
    Copyright (C) 2026  Janus Lammert

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

Contact: j.lammert@fz-juelich.de
