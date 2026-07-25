# Manual Webcam Stable v.1 — Panduan Pengguna

**Baca dulu sebelum menggunakan aplikasi.**

Manual Webcam Stable adalah aplikasi macOS untuk mengatur setelan webcam USB secara **langsung di hardware kamera** (brightness, exposure, focus, white balance, zoom, dan lainnya). Karena perubahan tersimpan di hardware webcam — bukan sekadar filter tampilan — hasilnya otomatis terbawa ke semua aplikasi lain: OBS, Zoom, Google Meet, Photo Booth, dan sebagainya.

| | |
|---|---|
| **Versi** | 1.0 (Stable) |
| **Kategori** | Utilities |
| **Sistem** | macOS 12.0 (Monterey) atau lebih baru |
| **Kamera yang didukung** | Webcam USB eksternal standar UVC (Logitech, Razer, AverMedia, dll.) |
| **Author** | [@khinccofficial](https://www.tiktok.com/@khinccofficial) |

---

## 1. Persyaratan & Hal Penting Sebelum Mulai

1. **Gunakan webcam USB eksternal.** Kamera internal MacBook (FaceTime HD) bukan perangkat UVC USB, jadi kontrol hardware tidak tersedia untuknya — aplikasi akan menampilkan pesan pemberitahuan. Ini normal.
2. **Izin kamera wajib diberikan.** Saat pertama dibuka, macOS akan meminta izin akses kamera. Pilih **Allow / Izinkan**. Kalau terlanjur menolak, aktifkan manual di: **System Settings → Privacy & Security → Camera → Manual Webcam Stable**.
3. **Koneksi internet** hanya dibutuhkan untuk fitur **Login Lisensi** (membuka Master Lock). Semua fitur pengaturan kamera lainnya berjalan offline.
4. Kalau webcam sedang dipakai aplikasi lain dan setelan menolak berubah, **tutup dulu aplikasi lain tersebut**, atur setelannya, lalu buka kembali.

## 2. Membuka Aplikasi Pertama Kali

1. Salin aplikasi ke folder **Applications**, lalu buka.
2. Jika muncul peringatan keamanan macOS (aplikasi dari luar App Store): klik kanan aplikasi → **Open** → **Open** sekali saja; selanjutnya bisa dibuka normal.
3. Berikan **izin kamera** saat diminta.
4. Pilih webcam Anda di dropdown **Webcam Source**. Tombol ⟳ dipakai untuk refresh daftar kalau webcam baru dicolok.

## 3. Mengenal Tampilan Aplikasi

Jendela terbagi dua kolom:

- **Kolom kiri** — pemilihan webcam, preview langsung, dan pengelolaan preset.
- **Kolom kanan** — semua kontrol setelan kamera (panel Color dan Lens).

### Panel Color

| Kontrol | Fungsi |
|---|---|
| Brightness | Terang/gelap gambar |
| Contrast | Perbedaan area terang dan gelap |
| Hue | Pergeseran rona warna |
| Saturation | Kepekatan warna (0 = hitam putih) |
| Sharpness | Ketajaman detail |
| Gamma | Kecerahan area tengah (midtone) |
| Backlight Comp | Kompensasi cahaya dari belakang objek |
| ISO/Gain | Penguatan sinyal sensor (untuk kondisi gelap) |
| White Balance + Auto | Suhu warna; centang Auto agar kamera mengatur sendiri |
| PowerLine | Anti kedip lampu — pilih **50 Hz** untuk Indonesia |
| **Color Tone (Red / Yellow / Blue)** | Preset nuansa warna cepat, lihat bagian 4 |

### Panel Lens

| Kontrol | Fungsi |
|---|---|
| Auto Exposure | Kamera mengatur pencahayaan otomatis; **matikan untuk mengatur Exposure manual** |
| Exposure | Lama sensor menangkap cahaya (hanya aktif saat Auto Exposure mati) |
| Low Light Comp | Kompensasi kondisi minim cahaya |
| Auto Focus | Fokus otomatis; matikan untuk mengatur Focus manual |
| Focus | Jarak fokus manual |
| Zoom | Perbesaran (umumnya webcam 4K) |
| Pan / Tilt | Geser kiri-kanan / atas-bawah (khusus webcam PTZ) |

> Kontrol yang tidak didukung webcam Anda akan otomatis nonaktif dengan keterangan "Tidak didukung kamera ini".
>
> Tombol ↺ kecil di ujung tiap slider mengembalikan **satu** setelan itu ke nilai default pabrik. Tombol **Reset Semua ke Default** di bawah mengembalikan semuanya sekaligus.

## 4. Color Tone: Red, Yellow, Blue

Tiga tombol cepat untuk mengubah nuansa warna gambar melalui white balance hardware:

- 🔴 **Red** — nuansa hangat kemerahan (temperatur paling rendah + dorongan hue)
- 🟡 **Yellow** — nuansa hangat kekuningan
- 🔵 **Blue** — nuansa dingin kebiruan (temperatur paling tinggi)

Saat tombol ditekan, **White Balance Auto otomatis dimatikan** agar nilai manual dipakai kamera. Untuk kembali normal: centang lagi **White Balance Auto**, atau tekan tombol ↺ di slider White Balance dan Hue.

## 5. Auto Exposure — Cara Pakai yang Benar

- **Auto Exposure ON** → kamera menyesuaikan pencahayaan sendiri mengikuti kondisi ruangan. Slider Exposure nonaktif (abu-abu).
- **Auto Exposure OFF** → slider Exposure aktif dan pencahayaan sepenuhnya di tangan Anda. Cocok untuk setup lighting studio yang tetap, supaya gambar tidak "bernapas" (berubah-ubah terang).

Setelah toggle diubah, aplikasi membaca ulang nilai dari hardware — jadi angka di slider selalu mencerminkan kondisi kamera sebenarnya.

## 6. Preset — Simpan & Panggil Setelan

Preset menyimpan seluruh nilai setelan kamera ke file, sehingga bisa dipanggil ulang kapan saja.

- **Save Preset** — ketik nama di kolom, klik Save Preset. Nama tidak boleh kosong atau kembar.
- **Load Preset** — pilih preset dari daftar, klik Load. Mode auto diterapkan lebih dulu, baru nilai manual.
- **Update Preset** — timpa preset terpilih dengan setelan saat ini.
- **Delete Preset** — hapus preset terpilih (ada konfirmasi; tidak bisa dibatalkan).
- **Kunci Preset** — klik kanan preset → **Kunci Preset**. Preset terkunci (ikon 🔒) tidak bisa diubah/dihapus sebelum Master Lock dibuka.
- **Export / Import .json** — bagikan preset antar komputer/pengguna: klik kanan → Export, atau tombol **Import…**.

Perhatikan indikator oranye *"perubahan BELUM disimpan"* — kalau muncul, setelan terbaru Anda belum masuk ke preset mana pun dan akan hilang jika di-load preset lain.

Lokasi penyimpanan preset: `~/Library/Application Support/WebcamSettingRuangVisual/Presets/`

## 7. Master Lock & Login Lisensi

- Tombol gembok di toolbar adalah **Master Lock** — pengaman untuk preset terkunci.
- Untuk membukanya diperlukan **login dengan password lisensi** (butuh internet). Setelah login sukses, status tersimpan dan Anda bisa buka/kunci preset dengan bebas.
- Password salah atau lisensi belum aktif akan ditolak server.

## 8. Pemecahan Masalah (Troubleshooting)

| Masalah | Solusi |
|---|---|
| Preview hitam / tidak muncul | Pastikan izin kamera diberikan (System Settings → Privacy & Security → Camera), lalu buka ulang aplikasi. |
| Webcam tidak ada di daftar | Cek kabel USB, lalu klik tombol refresh ⟳. Coba port USB lain (hindari hub tanpa daya). |
| Muncul pesan "Kontrol hardware UVC tidak tersedia" | Kamera yang dipilih bukan webcam UVC USB (misalnya kamera internal MacBook). Gunakan webcam USB eksternal. |
| Slider digeser tapi gambar tidak berubah | Matikan dulu mode Auto terkait (Auto Exposure untuk Exposure, Auto Focus untuk Focus, WB Auto untuk White Balance). |
| Pesan "kamera menolak request" | Webcam sedang dikunci aplikasi lain — tutup OBS/Zoom/Meet dulu, atur setelan, lalu buka lagi. |
| Gambar berkedip (flicker) | Set **PowerLine** ke 50 Hz (Indonesia) atau 60 Hz sesuai negara. |
| Login lisensi gagal terus | Periksa koneksi internet; pastikan password benar dan lisensi aktif. |
| Setelan kembali berubah sendiri | Sebagian webcam me-reset setelan saat dicabut-colok. Simpan setelan favorit sebagai **preset**, lalu Load setelah webcam terpasang. |

## 9. Pertanyaan Umum (FAQ)

**Apakah perubahan setelan terbawa ke Zoom/OBS/Meet?**
Ya. Setelan ditulis langsung ke hardware webcam, jadi berlaku di semua aplikasi.

**Apakah aplikasi merekam atau mengirim video saya?**
Tidak. Preview hanya ditampilkan di layar Anda. Satu-satunya koneksi keluar adalah verifikasi password lisensi.

**Kenapa sebagian slider tidak aktif?**
Setiap model webcam mendukung kontrol yang berbeda. Aplikasi otomatis menonaktifkan kontrol yang tidak didukung kamera Anda.

**Apakah preset dari versi Windows bisa dipakai?**
Tidak otomatis — skema file preset versi Windows berbeda.

---

© 2026 — Manual Webcam Stable v.1 · [@khinccofficial](https://www.tiktok.com/@khinccofficial)
