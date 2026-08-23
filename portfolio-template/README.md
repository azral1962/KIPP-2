# Template Portfolio Mahasiswa KIPP-2

Template repository Quarto untuk menyimpan materi belajar dan evidence
pencapaian mata kuliah **Komunikasi Inter Personal dan Publik**.

## Isi repository

- `course/`: pengantar, hasil belajar, slide, quiz, dan arahan evidence untuk 15 minggu.
- `slides/`: 15 deck RevealJS yang dapat dirender bersama situs.
- `portfolio/`: satu halaman evidence yang dapat diedit untuk setiap minggu.
- `assessment/`: siklus assessment, status pencapaian, dan rubrik universal.
- `.github/workflows/publish.yml`: publikasi otomatis ke GitHub Pages.
- `.github/ISSUE_TEMPLATE/assessment-request.yml`: formulir permintaan penilaian.

## Menjadikan repository ini template

1. Push isi folder ini ke repository GitHub baru.
2. Buka **Settings → General**.
3. Aktifkan **Template repository**.
4. Mahasiswa memilih **Use this template** untuk membuat repository miliknya.

Repository mahasiswa dapat dibuat private jika portfolio memuat evidence yang
tidak boleh dipublikasikan. Tambahkan dosen sebagai collaborator bila perlu.

## Personalisasi mahasiswa

Edit `_variables.yml` dan ganti seluruh placeholder identitas serta URL
repository. Jangan mengubah materi sumber kecuali dosen menginstruksikannya.

Untuk setiap minggu:

1. Baca halaman pada `course/week-XX.qmd`.
2. Buka slide dan kerjakan quiz formatif.
3. Isi `portfolio/week-XX.qmd` dengan evidence dan reflection.
4. Isi self-assessment, lalu ubah `status` menjadi `Siap dinilai`.
5. Commit dan push perubahan.
6. Buat issue **Permintaan assessment**.

Skor quiz tersimpan pada browser dan bukan nilai resmi. Nilai resmi harus
ditulis pada halaman portfolio berdasarkan evidence dan rubrik.

## Menjalankan secara lokal

Pasang Quarto, lalu jalankan dari root repository:

```powershell
quarto preview
```

Untuk menghasilkan seluruh situs dan slide:

```powershell
quarto render
```

## GitHub Pages

Workflow akan merender dan menerbitkan situs ke branch `gh-pages` setiap ada
push ke `main`. Pastikan GitHub Actions memiliki izin menulis ke repository.
Setelah workflow pertama selesai, periksa **Settings → Pages** dan pastikan
branch `gh-pages` digunakan sebagai sumber publikasi.

## Aturan assessment

- Nilai perilaku yang dapat diamati, bukan personality mahasiswa.
- Minta evidence untuk setiap klaim pencapaian.
- Bedakan kontribusi individual dari hasil kelompok.
- Minta deklarasi penggunaan AI.
- Berikan satu prioritas perbaikan yang dapat diuji melalui replay atau evidence berikutnya.

