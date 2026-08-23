# Slide Kuliah KIPP-2

Folder ini berisi 15 deck presentasi Quarto RevealJS untuk mata kuliah
Komunikasi Inter Personal dan Publik. Setiap deck dirancang untuk satu
pertemuan selama 120 menit.

## Struktur

- `minggu-01.qmd` sampai `minggu-15.qmd`: sumber slide mingguan.
- `_quarto.yml`: konfigurasi RevealJS dan proses render.
- `slides.scss`: tema visual bersama.
- `cover.png`: logo yang digunakan pada semua deck.
- `_site/`: hasil render HTML lokal; folder ini tidak dilacak Git.

## Render

Dari folder `slidss`, jalankan:

```powershell
quarto render
```

Untuk menampilkan satu deck selama pengembangan:

```powershell
quarto preview minggu-01.qmd
```

Hasil render berada di `_site`. Gunakan tombol panah untuk navigasi,
tekan `S` untuk membuka speaker view, dan tekan `B` untuk membuka chalkboard.

