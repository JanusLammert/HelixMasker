#!/bin/bash
# HelixMask — Linux Launcher
# Double-click in your file manager (mark executable first: chmod +x this file)
# or run from terminal. Handles environment creation automatically.

cd "$(dirname "$0")"
APPDIR="$(pwd)"
PORT=5173
ENV_NAME="helixmask"

# ── Try to open a terminal if run by double-click ──────────────
if [ -z "$TERM" ] && [ -z "$LAUNCHED_FROM_TERM" ]; then
    export LAUNCHED_FROM_TERM=1
    for TERM_EMU in gnome-terminal xterm konsole xfce4-terminal lxterminal mate-terminal tilix; do
        if command -v $TERM_EMU &>/dev/null; then
            case $TERM_EMU in
                gnome-terminal) $TERM_EMU -- bash "$0" ;;
                konsole)        $TERM_EMU -e bash "$0" ;;
                *)              $TERM_EMU -e bash "$0" ;;
            esac
            exit 0
        fi
    done
fi

clear
echo "╔══════════════════════════════════════════════╗"
echo "║      HelixMask — Cryo-EM Masking Tool        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Find conda/mamba ──────────────────────────────────────────
find_conda() {
    for candidate in \
        "$HOME/mambaforge/bin/mamba" \
        "$HOME/miniforge3/bin/mamba" \
        "$HOME/Miniforge3/bin/mamba" \
        "$HOME/micromamba/bin/micromamba" \
        "$HOME/opt/anaconda3/bin/conda" \
        "$HOME/anaconda3/bin/conda" \
        "$HOME/miniconda3/bin/conda" \
        "/opt/conda/bin/mamba" \
        "/opt/conda/bin/conda" \
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
    echo "   Install Miniforge (recommended):"
    echo "   https://github.com/conda-forge/miniforge/releases/latest"
    echo ""
    echo "   Or install via pip:"
    echo "     pip install -r requirements.txt && python app.py"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

CMD=$(basename "$CONDA_EXE")
echo "✔  Found: $CONDA_EXE"

# ── Source shell init ──────────────────────────────────────────
CONDA_BASE=$(dirname $(dirname "$CONDA_EXE"))
for init_script in \
    "$CONDA_BASE/etc/profile.d/conda.sh" \
    "$CONDA_BASE/etc/profile.d/mamba.sh"; do
    [ -f "$init_script" ] && source "$init_script"
done

# ── Create environment if needed ──────────────────────────────
if ! $CMD env list 2>/dev/null | grep -q "^${ENV_NAME}"; then
    echo ""
    echo "📦  Creating '${ENV_NAME}' environment (first run only, ~1-2 min)…"
    $CMD env create -f "$APPDIR/environment.yml" -y
    if [ $? -ne 0 ]; then
        echo "❌  Environment creation failed."
        read -p "Press Enter to exit..."
        exit 1
    fi
    echo "✔  Environment ready."
fi

# ── Locate python in the env ──────────────────────────────────
PYTHON=$($CMD run -n "$ENV_NAME" which python 2>/dev/null)
if [ -z "$PYTHON" ]; then
    ENV_PATH=$($CMD env list 2>/dev/null | grep "^${ENV_NAME}\s" | awk '{print $NF}')
    PYTHON="${ENV_PATH}/bin/python"
fi

if [ ! -x "$PYTHON" ]; then
    echo "❌  Cannot locate Python inside '${ENV_NAME}'."
    read -p "Press Enter to exit..."
    exit 1
fi

echo "✔  Python: $PYTHON"

# ── Check port ────────────────────────────────────────────────
if ss -tlnp 2>/dev/null | grep -q ":$PORT " || \
   netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
    echo "⚠   Port $PORT already in use — opening existing session."
    xdg-open "http://localhost:$PORT" 2>/dev/null || true
    read -p "Press Enter to exit..."
    exit 0
fi

# ── Launch ────────────────────────────────────────────────────
echo ""
echo "🚀  Starting HelixMask → http://localhost:$PORT"
echo "    Close this window to stop the server."
echo ""

(sleep 2 && xdg-open "http://localhost:$PORT" 2>/dev/null) &

"$PYTHON" "$APPDIR/app.py"

echo ""
read -p "Server stopped. Press Enter to close."
