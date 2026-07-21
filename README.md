# n8n Custom Task Runner (Debian 13)

Dokumentasi dan konfigurasi n8n Task Runner berbasis Debian 13 (Trixie) untuk eksekusi kode JavaScript (Node.js) dan Python pada lingkungan n8n.

Image ini dirancang sebagai pengganti stock runner berbasis Alpine Linux untuk memberikan dukungan glibc penuh serta mekanisme direktori persisten untuk modul custom Python dan Node.js.

## Fitur Utama

- **Debian 13 (glibc) Runtime**: Menghindari kendala kompatibilitas `musl` pada package C-extensions Python (`numpy`, `pandas`, `playwright`, `scipy`, `opencv`) dan native Node.js modules.
- **Default Installation Target**: Perintah `pip install`, `uv pip install`, dan `npm install` secara otomatis mengarah ke direktori persisten tanpa memerlukan parameter `--target` atau `--prefix`.
- **Persistensi Modul**: Seluruh pustaka yang diinstal tersimpan di host via volume mount, sehingga tidak hilang saat container direstart atau dibuild ulang.
- **Astral UV Pre-installed**: Menyediakan tool manajemen pustaka Python `uv` dan `uvx`.
- **Dukungan Paket APT**: Memungkinkan instalasi dependensi tingkat sistem (`apt-get`) seperti `ffmpeg`, `poppler-utils`, dan `tesseract-ocr`.

---

## Struktur Direktori

```text
n8n-runners-debian/
├── Dockerfile          # Multi-stage Dockerfile berbasis debian:13-slim
├── entrypoint.sh       # Script inisialisasi lingkungan dan virtualenv
├── docker-compose.yml  # Konfigurasi percontohan integrasi n8n dan runner
└── README.md           # Dokumentasi teknis
```

---

## Memulai

### 1. Build dan Jalankan Service

Jalankan perintah berikut untuk mem-build image dan menjalankan service via Docker Compose:

```bash
docker compose up -d --build
```

Secara otomatis, Docker akan membuat dua direktori persisten di host:
- `./n8n-runner-data/python` -> terhubung ke `/custom-python`
- `./n8n-runner-data/node` -> terhubung ke `/custom-node`

---

## Manajemen Paket Custom

### 1. Instalasi Paket Python

Perintah `pip` dan `uv` secara otomatis menginstall paket ke dalam direktori persisten `/custom-python`.

#### Menggunakan `pip`
```bash
docker exec -it n8n-runner-debian13 pip install playwright pandas requests
```

#### Menggunakan `uv`
```bash
docker exec -it n8n-runner-debian13 uv pip install playwright pandas requests
```

#### Instalasi Browser Playwright
Apabila menggunakan Playwright, jalankan perintah berikut untuk memasang dependensi browser:
```bash
docker exec -it n8n-runner-debian13 playwright install chromium --with-deps
```

---

### 2. Instalasi Paket Node.js

Perintah `npm` dan `pnpm` secara otomatis memasang modul ke direktori persisten `/custom-node`.

#### Menggunakan `npm`
```bash
docker exec -it n8n-runner-debian13 npm install lodash axios dayjs
```

#### Menggunakan `pnpm`
```bash
docker exec -it n8n-runner-debian13 pnpm add lodash axios
```

---

### 3. Instalasi Paket Sistem Debian (APT)

Untuk menginstall dependensi sistem yang dibutuhkan oleh workflow:

```bash
docker exec -u root -it n8n-runner-debian13 apt-get update && apt-get install -y ffmpeg poppler-utils tesseract-ocr
```

---

## Variabel Lingkungan (Environment Variables)

### 1. Variabel Lingkungan Bawaan (Stock n8n Runner & Core Integration)

| Variabel | Nilai Default / Contoh | Keterangan |
| :--- | :--- | :--- |
| `N8N_RUNNERS_AUTH_TOKEN` | `<secret-token>` | Token rahasia untuk autentikasi komunikasi antara n8n main instance dan runner launcher |
| `N8N_RUNNERS_ENABLED` | `true` | Mengaktifkan penggunaan task runner eksternal pada n8n main instance |
| `N8N_RUNNERS_MODE` | `external` | Mode eksekusi runner (`external` atau `internal`) |
| `N8N_RUNNERS_SERVER_URL` | `http://n8n-runner:5680` | URL endpoint server runner launcher |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS` | `0` | Menonaktifkan penegakan izin ketat pada file konfigurasi (jika bernilai `0`) |
| `NODE_ENV` | `production` | Lingkungan runtime aplikasi Node.js |
| `N8N_RELEASE_TYPE` | `dev` | Kategori tipe rilis versi n8n |
| `SHELL` | `/bin/bash` | Path interpreter shell default dalam container |

---

### 2. Variabel Lingkungan Custom Image (Debian 13 Persistent Integration)

| Variabel | Nilai Default | Keterangan |
| :--- | :--- | :--- |
| `VIRTUAL_ENV` | `/custom-python` | Menetapakan `/custom-python` sebagai Virtual Environment Python aktif utama |
| `PYTHONPATH` | `/custom-python/lib/python3.13/site-packages:...` | Path pencarian direktori modul Python |
| `PIP_TARGET` | `/custom-python/lib/python3.13/site-packages` | Lokasi target penginstalan otomatis untuk perintah `pip install` |
| `PIP_BREAK_SYSTEM_PACKAGES` | `1` | Mengizinkan penginstalan paket `pip` pada lingkungan terisolasi Debian (PEP 668) |
| `UV_PROJECT_ENVIRONMENT` | `/custom-python` | Menetapkan `/custom-python` sebagai target virtual environment default untuk `uv` |
| `UV_BREAK_SYSTEM_PACKAGES` | `1` | Mengizinkan penginstalan paket `uv` pada lingkungan terisolasi Debian (PEP 668) |
| `UV_PYTHON_INSTALL_DIR` | `/custom-python/uv-python` | Direktori penyimpanan versi Python mandiri yang diunduh oleh `uv` |
| `NODE_PATH` | `/custom-node/node_modules:...` | Path pencarian direktori modul Node.js |
| `NPM_CONFIG_PREFIX` | `/custom-node` | Prefix penginstalan modul global dan biner default untuk `npm` |
| `PNPM_HOME` | `/custom-node` | Direktori instalasi biner dan modul default untuk `pnpm` |
| `PATH` | `/custom-python/bin:/custom-node/bin:...` | Mengutamakan biner dari `/custom-python/bin` dan `/custom-node/bin` dalam sistem `PATH` |
