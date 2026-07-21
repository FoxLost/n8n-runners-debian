#!/usr/bin/env bash
set -e

# Create directories if accessible
mkdir -p /custom-python/lib/python3.13/site-packages /custom-python/bin /custom-node/node_modules /custom-node/bin 2>/dev/null || true

# Initialize virtualenv in /custom-python if missing
if [ ! -f "/custom-python/pyvenv.cfg" ]; then
    python3 -m venv --system-site-packages /custom-python 2>/dev/null || true
fi

# Inject custom-python site-packages path into n8n runner's python venv
PYTHON_VENV_LIB="/opt/runners/task-runner-python/.venv/lib"
if [ -d "$PYTHON_VENV_LIB" ]; then
    VENV_SITE_PACKAGES=$(find "$PYTHON_VENV_LIB" -maxdepth 2 -type d -name "site-packages" 2>/dev/null | head -n 1)
    if [ -n "$VENV_SITE_PACKAGES" ]; then
        echo "/custom-python/lib/python3.13/site-packages" > "$VENV_SITE_PACKAGES/custom_persistent_packages.pth" 2>/dev/null || true
        echo "/custom-python" >> "$VENV_SITE_PACKAGES/custom_persistent_packages.pth" 2>/dev/null || true
    fi
fi

# Symlink local node_modules to /custom-node/node_modules
if [ ! -e "/home/runner/node_modules" ]; then
    ln -sf /custom-node/node_modules /home/runner/node_modules 2>/dev/null || true
fi

# If arguments are passed (e.g. bash or pip install), execute them directly; otherwise start task-runner-launcher
if [ "$1" = "javascript" ] || [ "$1" = "python" ]; then
    exec tini -- /usr/local/bin/task-runner-launcher "$@"
else
    exec "$@"
fi
