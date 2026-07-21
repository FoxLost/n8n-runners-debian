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

## Variabel Lingkungan

| Variabel | Nilai Default | Keterangan |
| :--- | :--- | :--- |
| `VIRTUAL_ENV` | `/custom-python` | Menjadikan `/custom-python` sebagai virtual environment Python aktif |
| `PYTHONPATH` | `/custom-python/lib/python3.13/site-packages:...` | Menambahkan direktori paket kustom ke sys.path Python |
| `PIP_TARGET` | `/custom-python/lib/python3.13/site-packages` | Target penginstalan default untuk `pip` |
| `PIP_BREAK_SYSTEM_PACKAGES` | `1` | Mengizinkan penginstalan pip pada lingkungan Debian |
| `UV_PROJECT_ENVIRONMENT` | `/custom-python` | Target virtual environment default untuk `uv` |
| `NODE_PATH` | `/custom-node/node_modules:...` | Path pencarian modul Node.js |
| `NPM_CONFIG_PREFIX` | `/custom-node` | Prefix penginstalan global default untuk `npm` |
| `PNPM_HOME` | `/custom-node` | Direktori target default untuk `pnpm` |
