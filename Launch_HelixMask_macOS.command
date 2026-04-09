#!/bin/bash
# HelixMask — macOS Launcher
# Double-click this file to start HelixMask in your browser.
# On first run it will create the conda/mamba environment automatically.

# ── Change into the directory this script lives in ────────────
cd "$(dirname "$0")"
APPDIR="$(pwd)"

# ── Nice terminal title ────────────────────────────────────────
echo -e "\033]0;HelixMask\007"
clear
echo "╔══════════════════════════════════════════════╗"
echo "║         HelixMask — Cryo-EM Masking Tool     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

PORT=5173
ENV_NAME="helixmask"

# ── Find conda/mamba ──────────────────────────────────────────
find_conda() {
    for candidate in \
        "$HOME/mambaforge/bin/mamba" \
        "$HOME/miniforge3/bin/mamba" \
        "$HOME/micromamba/bin/micromamba" \
        "$HOME/opt/anaconda3/bin/conda" \
        "$HOME/anaconda3/bin/conda" \
        "$HOME/miniconda3/bin/conda" \
        "/opt/homebrew/bin/mamba" \
        "/usr/local/bin/mamba" \
        "$(which mamba 2>/dev/null)" \
        "$(which micromamba 2>/dev/null)" \
        "$(which conda 2>/dev/null)"; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

CONDA_EXE=$(find_conda)

if [ -z "$CONDA_EXE" ]; then
    echo "❌  Could not find conda, mamba, or micromamba."
    echo ""
    echo "   Please install Miniforge (recommended):"
    echo "   https://github.com/conda-forge/miniforge/releases/latest"
    echo ""
    echo "   Or run directly with pip:"
    echo "     pip install -r requirements.txt && python app.py"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

echo "✔  Found: $CONDA_EXE"

# ── Initialise conda shell functions ──────────────────────────
CONDA_BASE=$(dirname $(dirname "$CONDA_EXE"))
if [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
    source "$CONDA_BASE/etc/profile.d/conda.sh"
elif [ -f "$CONDA_BASE/etc/profile.d/mamba.sh" ]; then
    source "$CONDA_BASE/etc/profile.d/mamba.sh"
fi

# Determine the command name (conda / mamba / micromamba)
CMD=$(basename "$CONDA_EXE")

# ── Create environment if needed ──────────────────────────────
if ! $CMD env list 2>/dev/null | grep -q "^${ENV_NAME}"; then
    echo ""
    echo "📦  Creating '${ENV_NAME}' environment (first run only, ~1 min)…"
    $CMD env create -f "$APPDIR/environment.yml" -y
    if [ $? -ne 0 ]; then
        echo "❌  Environment creation failed."
        read -p "Press Enter to exit..."
        exit 1
    fi
    echo "✔  Environment created."
fi

# ── Activate environment ───────────────────────────────────────
echo "⚡  Activating environment…"
$CMD activate "$ENV_NAME" 2>/dev/null || conda activate "$ENV_NAME" 2>/dev/null

# Find python in the environment
PYTHON=$(conda run -n "$ENV_NAME" which python 2>/dev/null || \
         $CMD run -n "$ENV_NAME" which python 2>/dev/null)

if [ -z "$PYTHON" ]; then
    # Fallback: locate environment folder directly
    ENV_PATH=$($CMD env list 2>/dev/null | grep "^${ENV_NAME}" | awk '{print $NF}')
    PYTHON="${ENV_PATH}/bin/python"
fi

if [ ! -x "$PYTHON" ]; then
    echo "❌  Cannot locate Python in the '${ENV_NAME}' environment."
    read -p "Press Enter to exit..."
    exit 1
fi

echo "✔  Python: $PYTHON"

# ── Check port availability ────────────────────────────────────
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠   Port $PORT is already in use — opening existing session."
    open "http://localhost:$PORT"
    read -p "Press Enter to exit..."
    exit 0
fi

# ── Launch Flask server ────────────────────────────────────────
echo ""
echo "🚀  Starting HelixMask on http://localhost:$PORT"
echo "    (Close this window to stop the server)"
echo ""

# Open browser after a short delay
(sleep 2 && open "http://localhost:$PORT") &

"$PYTHON" "$APPDIR/app.py"

echo ""
echo "Server stopped. Press Enter to close."
read -p ""
