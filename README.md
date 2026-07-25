# Webcam Setting Ruang Visual — Port macOS (v3.2.0)

Port native macOS dari `Webcam_Setting_Ruang_Visual_Version_3_2_0.exe` (WinForms + DirectShowLib) ke **SwiftUI + AVFoundation + IOKit UVC**.

Perbedaan arsitektur inti: di Windows kontrol hardware pakai `IAMVideoProcAmp` / `IAMCameraControl` (DirectShow). Di macOS tidak ada API publik setara, jadi app ini mengirim **UVC class request langsung ke USB Video Control interface** (GET_MIN/GET_MAX/GET_CUR/SET_CUR). Hasilnya sama seperti versi Windows: perubahan tersimpan di **hardware webcam** dan terbawa ke OBS, Zoom, Google Meet, dll — bukan sekadar filter preview.

## Pemetaan fitur Windows → macOS

| Fitur Windows (.exe) | Implementasi macOS | Status |
|---|---|---|
| Pilih webcam + Refresh | `AVCaptureDevice.DiscoverySession` (`.external`/`.externalUnknown`) | ✅ |
| Preview (`FormPreview`) | `AVCaptureVideoPreviewLayer`, toggle di window utama | ✅ |
| Brightness/Contrast/Hue/Saturation/Sharpness/Gamma | UVC Processing Unit selector 0x02–0x09 | ✅ |
| White Balance + Auto | PU 0x0A / 0x0B | ✅ |
| Backlight Comp, ISO/Gain | PU 0x01 / 0x04 | ✅ |
| PowerLine 50/60 Hz | PU 0x05 | ✅ |
| Exposure + Auto | Camera Terminal 0x04 / AE Mode 0x02 | ✅ |
| Low Light (`chkLowLight`) | CT AE Priority 0x03 (padanan UVC terdekat) | ✅ |
| Focus + Auto Focus | CT 0x06 / 0x08 | ✅ |
| Zoom / Pan / Tilt (PTZ) | CT 0x0B / 0x0D (pan+tilt satu request 8 byte) | ✅ |
| Preset save/update/load/delete (.json) | `PresetManager` → `~/Library/Application Support/WebcamSettingRuangVisual/Presets/` | ✅ |
| Preset terkunci + Master Lock | flag `locked` + toolbar Master Lock (butuh login) | ✅ |
| Login lisensi (Cloudflare worker) | `AuthManager` → endpoint yang sama | ✅ (cek format request, lihat bawah) |
| Reset Preset | tombol "Reset Semua ke Default" (GET_DEF hardware) | ✅ |
| Update checker (`FormUpdate`) | tidak diport (distribusi macOS beda jalur) | ➖ |
| Custom borderless window | pakai title bar native macOS | diganti |

## Build (Xcode di MacBook)

**Cara A — XcodeGen (paling cepat):**
```bash
brew install xcodegen
cd WSRV-macOS
xcodegen
open WebcamSettingRuangVisual.xcodeproj
```

**Cara B — manual:**
1. Xcode → New Project → macOS → **App** → nama `WebcamSettingRuangVisual`, interface SwiftUI.
2. Hapus `ContentView.swift` bawaan, drag semua isi folder `WebcamSettingRuangVisual/` ke project (Copy items if needed).
3. Target → Info: tambah `NSCameraUsageDescription`.
4. Target → Signing & Capabilities:
   - **Matikan App Sandbox** (atau kalau tetap sandbox: tambah entitlement `com.apple.security.device.usb`).
   - Aktifkan **Camera** dan **Outgoing Connections (Client)**.
5. Build & Run (⌘R).

> Kenapa sandbox dimatikan: IOKit USB butuh akses device. Untuk distribusi luar App Store (notarized .dmg) ini normal. Kalau mau App Store, pakai sandbox + `device.usb`.

## Checklist testing di MacBook

1. **Discovery**: webcam USB eksternal muncul di dropdown; tombol refresh mendeteksi plug/unplug.
2. **Preview** jalan setelah izin kamera diberikan.
3. Geser **Brightness** → cek perubahan terlihat juga di aplikasi lain (Photo Booth/OBS) → berarti kontrol hardware sukses.
4. **Auto ↔ Manual**: matikan Auto Exposure lalu geser Exposure; matikan Auto Focus lalu geser Focus.
5. **Preset**: Save → ubah slider → Load → nilai kembali. Update, Delete (dengan konfirmasi), Lock via klik kanan.
6. **Master Lock**: preset terkunci menolak update/delete sebelum login.
7. **Import/Export .json** antar mesin.
8. Kamera **internal MacBook (FaceTime HD)**: bukan UVC USB — app menampilkan pesan "Kontrol hardware UVC tidak tersedia", ini expected. Fitur penuh berlaku untuk **webcam USB eksternal** (Logitech, dll).

## Catatan penting

- **Login worker**: versi Windows mengirim payload gaya record `{ password = ... }`. Port ini mengirim JSON `{"password": "..."}` dan menganggap HTTP 2xx tanpa kata "invalid/salah/false" = sukses. Kalau worker kamu balas format lain, sesuaikan satu fungsi saja: `AuthManager.makeRequest` + logika `ok` di `login()`.
- **Exclusive access**: beberapa webcam menolak `USBInterfaceOpen` saat dipakai app lain; kode sudah fallback (`ExclusiveAccess` tetap lanjut, lalu `OpenSeize`). Kalau ada model yang tetap menolak SET_CUR saat streaming, tutup app lain dulu, set, lalu buka lagi.
- **Pan/Tilt** di UVC adalah satu kontrol gabungan 8 byte — sudah ditangani dengan cache internal.
- Preset `.json` dari versi Windows **tidak** otomatis kompatibel (skemanya beda); kalau mau kompatibel dua arah, kirim contoh file preset Windows-nya nanti saya buatkan konverter.
