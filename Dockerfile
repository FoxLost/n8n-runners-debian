# ==============================================================================
# n8n Task Runner - Debian 13 (Trixie) Custom Build
# Base OS: debian:13-slim (glibc)
# Enables easy custom package installation (pip, uv, npm, apt)
# Persists installed modules using host volume mounts (/custom-python, /custom-node)
# ==============================================================================

ARG NODE_VERSION=24.16.0
ARG PYTHON_VERSION=3.13
ARG DEBIAN_VERSION=13-slim
ARG PNPM_VERSION=10.32.1
ARG UV_VERSION=0.8.14
ARG LAUNCHER_VERSION=1.4.7

# ==============================================================================
# STAGE 1: JavaScript Runner Builder (@n8n/task-runner)
# ==============================================================================
FROM node:${NODE_VERSION}-slim AS javascript-runner-builder
ARG PNPM_VERSION

WORKDIR /app/task-runner-javascript

# Copy build context safely
COPY . /tmp/repo/
RUN if [ -d "/tmp/repo/dist/task-runner-javascript" ]; then \
        cp -r /tmp/repo/dist/task-runner-javascript/* /app/task-runner-javascript/; \
    fi && rm -rf /tmp/repo

RUN if [ -f "./package.json" ]; then \
        corepack enable pnpm && corepack prepare "pnpm@${PNPM_VERSION}" --activate; \
        node -e "const pkg = require('./package.json'); \
            Object.keys(pkg.dependencies || {}).forEach(k => { \
                const val = pkg.dependencies[k]; \
                if (val === 'catalog:' || val.startsWith('catalog:') || val.startsWith('workspace:')) \
                    delete pkg.dependencies[k]; \
            }); \
            Object.keys(pkg.devDependencies || {}).forEach(k => { \
                const val = pkg.devDependencies[k]; \
                if (val === 'catalog:' || val.startsWith('catalog:') || val.startsWith('workspace:')) \
                    delete pkg.devDependencies[k]; \
            }); \
            delete pkg.devDependencies; \
            require('fs').writeFileSync('./package.json', JSON.stringify(pkg, null, 2));"; \
        rm -f node_modules/.modules.yaml && pnpm add moment@2.30.1 --prod --no-lockfile || true; \
    else \
        mkdir -p /app/task-runner-javascript/dist && \
        echo 'console.log("JavaScript task runner initialized");' > /app/task-runner-javascript/dist/index.js; \
    fi

# ==============================================================================
# STAGE 2: Python Runner Builder (@n8n/task-runner-python)
# ==============================================================================
FROM debian:${DEBIAN_VERSION} AS python-runner-builder
ARG UV_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install uv for glibc (x86_64 / aarch64)
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "$ARCH" in \
        "amd64") UV_ARCH="x86_64-unknown-linux-gnu" ;; \
        "arm64") UV_ARCH="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported platform: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz" | tar -xz -C /tmp; \
    install -m 0755 "/tmp/uv-${UV_ARCH}/uv" /usr/local/bin/uv; \
    rm -rf /tmp/uv-*

WORKDIR /app/task-runner-python

# Copy build context safely
COPY . /tmp/repo/
RUN if [ -d "/tmp/repo/packages/@n8n/task-runner-python" ]; then \
        cp -r /tmp/repo/packages/@n8n/task-runner-python/* /app/task-runner-python/; \
    fi && rm -rf /tmp/repo

RUN if [ -f "pyproject.toml" ]; then \
        uv venv && \
        uv sync --frozen --no-dev --all-extras --no-editable || true; \
        uv pip install . || true; \
        rm -rf /app/task-runner-python/src; \
    else \
        python3 -m venv /app/task-runner-python/.venv; \
    fi

# ==============================================================================
# STAGE 3: Task Runner Launcher Downloader
# ==============================================================================
FROM debian:${DEBIAN_VERSION} AS launcher-downloader
ARG LAUNCHER_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates tar \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "$ARCH" in \
        "amd64") ARCH_NAME="amd64" ;; \
        "arm64") ARCH_NAME="arm64" ;; \
        *) echo "Unsupported platform: $ARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /launcher-bin; \
    curl -fsSL "https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz" | tar -xz -C /launcher-bin

# ==============================================================================
# STAGE 4: Debian 13 (Trixie) Final Runtime
# ==============================================================================
FROM debian:${DEBIAN_VERSION} AS runtime

ARG NODE_VERSION
ARG UV_VERSION
ARG N8N_VERSION=snapshot
ARG N8N_RELEASE_TYPE=dev

# Install system dependencies, C/C++ compilation toolchain, Python3 & utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    tini \
    jq \
    sudo \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install official Node.js binaries (glibc x64 / arm64)
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "$ARCH" in \
        "amd64") NODE_ARCH="x64" ;; \
        "arm64") NODE_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" | tar -xJ -C /usr/local --strip-components=1; \
    node --version; \
    npm --version

# Enable corepack and pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install Astral UV (glibc x86_64 / aarch64)
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "$ARCH" in \
        "amd64") UV_ARCH="x86_64-unknown-linux-gnu" ;; \
        "arm64") UV_ARCH="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz" | tar -xz -C /tmp; \
    install -m 0755 "/tmp/uv-${UV_ARCH}/uv" /usr/local/bin/uv; \
    install -m 0755 "/tmp/uv-${UV_ARCH}/uvx" /usr/local/bin/uvx; \
    rm -rf /tmp/uv-*

# Create non-root runner user (UID 1000)
RUN groupadd -g 1000 runner \
    && useradd -u 1000 -g runner -m -s /bin/bash runner

# Prepare persistent module mount paths with proper permissions
RUN mkdir -p /custom-python /custom-node /opt/runners \
    && chown -R runner:runner /custom-python /custom-node /opt/runners

WORKDIR /home/runner

# Copy built task runners and launcher
COPY --from=javascript-runner-builder --chown=runner:runner /app/task-runner-javascript /opt/runners/task-runner-javascript
COPY --from=python-runner-builder --chown=runner:runner /app/task-runner-python /opt/runners/task-runner-python
COPY --from=launcher-downloader /launcher-bin/* /usr/local/bin/

# Default n8n task runners configuration
RUN mkdir -p /etc && \
    echo '{\
  "taskRunners": {\
    "javascript": {\
      "command": "/usr/local/bin/node",\
      "args": ["/opt/runners/task-runner-javascript/dist/index.js"]\
    },\
    "python": {\
      "command": "/opt/runners/task-runner-python/.venv/bin/python",\
      "args": ["-m", "n8n_task_runner_python"]\
    }\
  }\
}' > /etc/n8n-task-runners.json

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Environment variables for custom package discovery & persistent volume mounts
ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE} \
    SHELL=/bin/bash \
    VIRTUAL_ENV="/custom-python" \
    PYTHONPATH="/custom-python/lib/python3.13/site-packages:/custom-python/lib/python3/site-packages:/custom-python" \
    NODE_PATH="/custom-node/node_modules:/opt/runners/task-runner-javascript/node_modules" \
    PATH="/custom-python/bin:/custom-node/bin:/home/runner/.local/bin:${PATH}" \
    PIP_TARGET="/custom-python/lib/python3.13/site-packages" \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    UV_BREAK_SYSTEM_PACKAGES=1 \
    NPM_CONFIG_PREFIX="/custom-node" \
    PNPM_HOME="/custom-node" \
    UV_PROJECT_ENVIRONMENT="/custom-python" \
    UV_PYTHON_INSTALL_DIR="/custom-python/uv-python"

USER runner

EXPOSE 5680/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["javascript", "python"]

LABEL org.opencontainers.image.title="n8n task runners (Debian 13)" \
      org.opencontainers.image.description="Debian 13 (glibc) sidecar image for n8n task runners supporting persistent custom modules" \
      org.opencontainers.image.version="${N8N_VERSION}"
