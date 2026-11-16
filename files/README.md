# xdfaaa ai

Chat AI lokal dengan Qwen3-4B-abliterated (GGUF Q4_K_M).
Semua data (model + chat) disimpan di perangkat.

## Build

1. Isi `config.json` (di folder deploy/) dengan token & link repo.
2. Jalankan `python push.py`.
3. Buka GitHub → Actions → **Build xdfaaa ai APK** → **Run workflow**.
4. Unduh APK dari **Artifacts**.

## Fitur

- Izin penyimpanan → unduh model → chat (alur awal).
- Chat multi-turn (riwayat otomatis dilanjutkan).
- Long-press bubble → salin pesan.
- Blok kode punya tombol salin sendiri.
- Pengaturan (⚙️) → simpan GitHub token & link repo (bisa diganti) untuk backup chat.
