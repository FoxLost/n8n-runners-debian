#!/usr/bin/env bash
set -e

# Fix ownership of host-mounted volume directories if owned by root
if [ -d "/custom-python" ] || [ -d "/custom-node" ]; then
    sudo chown -R runner:runner /custom-python /custom-node 2>/dev/null || true
fi

# Ensure subdirectories exist
mkdir -p /custom-python /custom-node/node_modules /custom-node/bin

# Initialize virtualenv in /custom-python if missing or incomplete
if [ ! -f "/custom-python/pyvenv.cfg" ]; then
    echo "[entrypoint] Initializing Python virtual environment in /custom-python..."
    python3 -m venv --system-site-packages /custom-python
fi

# Inject custom-python site-packages path into n8n runner's python venv
PYTHON_VENV_LIB="/opt/runners/task-runner-python/.venv/lib"
if [ -d "$PYTHON_VENV_LIB" ]; then
    VENV_SITE_PACKAGES=$(find "$PYTHON_VENV_LIB" -maxdepth 2 -type d -name "site-packages" 2>/dev/null | head -n 1)
    if [ -n "$VENV_SITE_PACKAGES" ]; then
        echo "/custom-python/lib/python3.13/site-packages" > "$VENV_SITE_PACKAGES/custom_persistent_packages.pth"
        echo "/custom-python" >> "$VENV_SITE_PACKAGES/custom_persistent_packages.pth"
    fi
fi

# Symlink local node_modules to /custom-node/node_modules
if [ ! -e "/home/runner/node_modules" ]; then
    ln -sf /custom-node/node_modules /home/runner/node_modules 2>/dev/null || true
fi

# If arguments are passed, execute them; otherwise start launcher
if [ "$1" = "javascript" ] || [ "$1" = "python" ]; then
    exec tini -- /usr/local/bin/task-runner-launcher "$@"
else
    exec "$@"
fi
