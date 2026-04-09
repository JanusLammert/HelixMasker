#!/usr/bin/env python3
"""
HelixMask — Interactive Cryo-EM Helical Density Map Masking Tool
Supports RELION and cryoSPARC helical reconstructions (.mrc / .mrcs)

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
"""

import os
import io
import json
import base64
import tempfile
import traceback

import numpy as np
from scipy import ndimage
from scipy.ndimage import distance_transform_edt
from flask import Flask, request, jsonify, send_file, render_template
from PIL import Image
import mrcfile

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 2 * 1024 * 1024 * 1024  # 2 GB upload limit

# ─── Global in-memory state ────────────────────────────────────────────────────
state = {
    "volume": None,       # np.ndarray float32 (nz, ny, nx)
    "apix": 1.0,          # Ångström per pixel
    "filename": None,
    "shape": None,        # (nz, ny, nx)
}


# ─── Utility helpers ───────────────────────────────────────────────────────────

def get_slice(volume, view_axis, index):
    """Return a 2D slice. view_axis: 0=XY(Z-slice), 1=XZ(Y-slice), 2=YZ(X-slice)"""
    if view_axis == 0:
        return volume[index, :, :]
    elif view_axis == 1:
        return volume[:, index, :]
    else:
        return volume[:, :, index]


def normalize(sl, low_pct=2.0, high_pct=98.0):
    vmin = np.percentile(sl, low_pct)
    vmax = np.percentile(sl, high_pct)
    return np.clip((sl - vmin) / (vmax - vmin + 1e-9), 0.0, 1.0)


def to_b64_png(arr_float):
    """Convert float [0,1] 2D array → base64-encoded PNG string."""
    img = Image.fromarray((arr_float * 255).astype(np.uint8), mode="L")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


# ─── Helical symmetry ──────────────────────────────────────────────────────────

def apply_helical_symmetry(mask_2d, volume_shape, rise_px, twist_deg, helix_axis=2):
    """
    Extend a 2D cross-sectional mask into a full 3D helical mask.

    Parameters
    ----------
    mask_2d     : 2D float32 array, the drawn cross-section
    volume_shape: (nz, ny, nx)
    rise_px     : helical rise in voxels
    twist_deg   : twist per rise unit in degrees
    helix_axis  : 0=X, 1=Y, 2=Z (axis the helix runs along)
    """
    nz, ny, nx = volume_shape
    mask_3d = np.zeros(volume_shape, dtype=np.float32)

    def rotated(mask, angle):
        rot = ndimage.rotate(mask, angle, reshape=False, order=1,
                             mode="constant", cval=0.0, prefilter=False)
        return np.clip(rot, 0.0, 1.0)

    if helix_axis == 2:  # helix along Z → cross-section is XY plane
        center = nz // 2
        for z in range(nz):
            angle = (z - center) / rise_px * twist_deg if rise_px != 0 else 0.0
            mask_3d[z] = rotated(mask_2d, angle)

    elif helix_axis == 1:  # helix along Y → cross-section is XZ plane
        center = ny // 2
        for y in range(ny):
            angle = (y - center) / rise_px * twist_deg if rise_px != 0 else 0.0
            mask_3d[:, y, :] = rotated(mask_2d, angle)

    elif helix_axis == 0:  # helix along X → cross-section is YZ plane
        center = nx // 2
        for x in range(nx):
            angle = (x - center) / rise_px * twist_deg if rise_px != 0 else 0.0
            mask_3d[:, :, x] = rotated(mask_2d, angle)

    return mask_3d


def apply_soft_edge(mask_3d, edge_px):
    """
    Apply RELION-style cosine soft edge to a 3D binary mask.
    Edge values fall from 1→0 over `edge_px` voxels using a cosine profile.
    """
    if edge_px <= 0:
        return mask_3d.astype(np.float32)

    binary = mask_3d > 0.5
    dist_out = distance_transform_edt(~binary)

    soft = np.where(binary, 1.0, 0.0).astype(np.float32)
    in_edge = (~binary) & (dist_out <= edge_px)
    d = dist_out[in_edge]
    soft[in_edge] = 0.5 * (1.0 + np.cos(np.pi * d / edge_px))
    return soft


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/upload", methods=["POST"])
def upload():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400
    f = request.files["file"]
    if not f.filename:
        return jsonify({"error": "Empty filename"}), 400

    try:
        ext = ".mrcs" if f.filename.lower().endswith(".mrcs") else ".mrc"
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
            f.save(tmp.name)
            tmp_path = tmp.name

        with mrcfile.open(tmp_path, mode="r", permissive=True) as mrc:
            data = mrc.data.copy().astype(np.float32)
            vsize = mrc.voxel_size
            apix = float(vsize.x) if float(vsize.x) > 0 else 1.0
            header = {
                "nx": int(mrc.header.nx), "ny": int(mrc.header.ny),
                "nz": int(mrc.header.nz), "mode": int(mrc.header.mode),
            }

        os.unlink(tmp_path)

        # Handle 2D stacks and edge cases
        if data.ndim == 2:
            data = data[np.newaxis, ...]
        if data.ndim == 4:
            data = data[0]  # take first frame of 4D
        if data.ndim != 3:
            return jsonify({"error": f"Unexpected data shape: {data.shape}"}), 400

        state["volume"] = data
        state["apix"] = apix
        state["filename"] = f.filename
        state["shape"] = data.shape

        nz, ny, nx = data.shape
        mid = nz // 2
        sl = normalize(get_slice(data, 0, mid))

        # Basic statistics
        stats = {
            "min": float(data.min()), "max": float(data.max()),
            "mean": float(data.mean()), "std": float(data.std()),
        }

        return jsonify({
            "shape": list(data.shape),
            "apix": apix,
            "filename": f.filename,
            "mid_index": mid,
            "slice_image": to_b64_png(sl),
            "header": header,
            "stats": stats,
        })

    except Exception as e:
        return jsonify({"error": str(e), "detail": traceback.format_exc()}), 500


@app.route("/slice")
def get_slice_route():
    if state["volume"] is None:
        return jsonify({"error": "No volume loaded"}), 400

    view_axis = int(request.args.get("axis", 0))
    index = int(request.args.get("index", 0))
    low = float(request.args.get("low", 2.0))
    high = float(request.args.get("high", 98.0))

    try:
        nz, ny, nx = state["shape"]
        max_idx = [nz - 1, ny - 1, nx - 1][view_axis]
        index = max(0, min(index, max_idx))

        sl = normalize(get_slice(state["volume"], view_axis, index), low, high)
        h, w = sl.shape
        return jsonify({
            "image": to_b64_png(sl),
            "shape": [h, w],
            "index": index,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/preview", methods=["POST"])
def preview():
    """Generate a downsampled preview of the symmetrized 3D mask."""
    if state["volume"] is None:
        return jsonify({"error": "No volume loaded"}), 400

    d = request.json
    try:
        mask_2d = np.array(d["mask"], dtype=np.float32)
        rise_px = float(d["rise"]) / state["apix"]
        twist = float(d["twist"])
        helix_axis = int(d.get("helix_axis", 2))
        edge_px = float(d.get("soft_edge", 6.0)) / state["apix"]

        vol_shape = state["shape"]
        nz, ny, nx = vol_shape

        # Downsample for fast preview (target ≤96 in each dim)
        MAX_DIM = 96
        scale = min(1.0, MAX_DIM / max(vol_shape))
        if scale < 1.0:
            mask_ds = ndimage.zoom(mask_2d, scale, order=1)
            shape_ds = tuple(max(1, round(s * scale)) for s in vol_shape)
            rise_ds = max(0.5, rise_px * scale)
            edge_ds = edge_px * scale
        else:
            mask_ds = mask_2d
            shape_ds = vol_shape
            rise_ds = rise_px
            edge_ds = edge_px

        mask_3d = apply_helical_symmetry(mask_ds, shape_ds, rise_ds, twist, helix_axis)
        mask_soft = apply_soft_edge(mask_3d, edge_ds)

        ndz, ndy, ndx = shape_ds
        previews = {}

        if helix_axis == 2:
            previews["side"] = to_b64_png(mask_soft[:, ndy // 2, :])
            for frac, key in [(0.25, "z25"), (0.5, "z50"), (0.75, "z75")]:
                z = max(0, min(ndz - 1, round(frac * ndz)))
                previews[key] = to_b64_png(mask_soft[z, :, :])
        elif helix_axis == 1:
            previews["side"] = to_b64_png(mask_soft[:, ndy // 2, :])
            for frac, key in [(0.25, "z25"), (0.5, "z50"), (0.75, "z75")]:
                y = max(0, min(ndy - 1, round(frac * ndy)))
                previews[key] = to_b64_png(mask_soft[:, y, :])
        else:
            previews["side"] = to_b64_png(mask_soft[:, :, ndx // 2])
            for frac, key in [(0.25, "z25"), (0.5, "z50"), (0.75, "z75")]:
                x = max(0, min(ndx - 1, round(frac * ndx)))
                previews[key] = to_b64_png(mask_soft[:, :, x])

        vol_frac = float(np.sum(mask_soft > 0.5) / mask_soft.size * 100)
        return jsonify({
            "previews": previews,
            "stats": {
                "volume_fraction": round(vol_frac, 2),
                "rise_px": round(rise_px, 2),
                "edge_px": round(edge_px, 1),
                "mask_voxels": int(np.sum(mask_soft > 0.5)),
                "total_voxels": int(mask_soft.size),
            },
        })

    except Exception as e:
        return jsonify({"error": str(e), "detail": traceback.format_exc()}), 500


@app.route("/export", methods=["POST"])
def export_mask():
    """Generate full-resolution 3D helical mask and return as MRC file."""
    if state["volume"] is None:
        return jsonify({"error": "No volume loaded"}), 400

    d = request.json
    tmp_path = None
    try:
        mask_2d = np.array(d["mask"], dtype=np.float32)
        rise_px = float(d["rise"]) / state["apix"]
        twist = float(d["twist"])
        helix_axis = int(d.get("helix_axis", 2))
        edge_px = float(d.get("soft_edge", 6.0)) / state["apix"]
        out_name = str(d.get("filename", "helical_mask")) + ".mrc"

        mask_3d = apply_helical_symmetry(
            mask_2d, state["shape"], rise_px, twist, helix_axis
        )
        mask_soft = apply_soft_edge(mask_3d, edge_px)

        with tempfile.NamedTemporaryFile(suffix=".mrc", delete=False) as tmp:
            tmp_path = tmp.name

        with mrcfile.new(tmp_path, overwrite=True) as mrc:
            mrc.set_data(mask_soft.astype(np.float32))
            mrc.voxel_size = state["apix"]

        return send_file(
            tmp_path, as_attachment=True,
            download_name=out_name,
            mimetype="application/octet-stream",
        )

    except Exception as e:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
        return jsonify({"error": str(e), "detail": traceback.format_exc()}), 500


# ─── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    host = "0.0.0.0"
    port = 5173
    print("╔══════════════════════════════════════════╗")
    print("║         HelixMask — Cryo-EM Tool         ║")
    print(f"║   → http://localhost:{port}               ║")
    print("╚══════════════════════════════════════════╝")
    app.run(debug=False, host=host, port=port)
