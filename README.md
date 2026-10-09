# F Loafinwatch 📱📊

Aplikasi pendamping (companion app) pemantauan finansial, transaksi, dan payout developer secara real-time yang terhubung langsung dengan backend **Loa-Cahaya-Ilmu-Bangsa**. Dilengkapi dengan Android Homescreen Widgets dan integrasi Firebase Cloud Messaging (FCM).

---

## ✨ Fitur Utama
1. **Real-time Homescreen Widgets**: Menampilkan ringkasan hak developer, saldo yang belum dicairkan, status payout terbaru, dan grafik tren 7 hari langsung di homescreen HP tanpa harus membuka aplikasi.
2. **Push Notifikasi FCM (100% Free)**: Menerima notifikasi otomatis saat pembayaran payout QRIS selesai diproses oleh admin.
3. **Background Widget Sync**: Saat notifikasi FCM diterima di latar belakang, widget homescreen secara otomatis diperbarui (update silent) tanpa perlu interaksi pengguna.
4. **Keamanan Biometrik & PIN**: Perlindungan ganda dengan Fingerprint/Face ID dan fallback PIN 6 digit.
5. **Detail Transaksi & Payout**: Menyaring transaksi (termasuk paket author & add-on DOI) serta mengonfirmasi/menolak penerimaan payout.

---

## 🔔 Panduan Konfigurasi Firebase & Notifikasi

Aplikasi ini menggunakan Firebase Cloud Messaging (FCM) pada paket gratis (Spark Plan, $0 selamanya) via protokol modern **FCM HTTP v1**.

### 1. File Konfigurasi Firebase Android
* Unduh file `google-services.json` dari [Firebase Console](https://console.firebase.google.com/) pada project **floafinwatch** (Package Name: `com.example.floafinwatch`).
* Letakkan file tersebut di direktori:
  ```
  floafinwatch/android/app/google-services.json
  ```

### 2. Konfigurasi Gradle Android (Sudah Dikonfigurasi)
* **Root Settings** (`android/settings.gradle.kts`): Plugin `com.google.gms.google-services` versi `4.4.2`.
* **App Gradle** (`android/app/build.gradle.kts`):
  * Plugin `com.google.gms.google-services`.
  * `isCoreLibraryDesugaringEnabled = true` di dalam `compileOptions`.
  * Dependency `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` untuk dukungan notifikasi Android.
* **Manifest** (`android/app/src/main/AndroidManifest.xml`):
  * Izin `android.permission.POST_NOTIFICATIONS`.
  * Default notification channel `floafinwatch_payouts`.

### 3. Alur Kerja Registrasi Token & Background Sync
* **Registrasi Token**: Saat developer login ke aplikasi, `FcmService.syncTokenWithBackend()` akan otomatis memanggil API `POST /api/v1/developer/fcm-token` untuk menyimpan token perangkat di database backend.
* **Background Handler**: Fungsi `@pragma('vm:entry-point') firebaseMessagingBackgroundHandler` di `lib/services/fcm_service.dart` mendeteksi payload `action: 'sync_widgets'` untuk merender dan mengupdate widget secara realtime di homescreen.

---

## 🚀 Cara Menjalankan Aplikasi

### Mode Server Online (Default: `https://loa.jurnalcib.com/api/v1`)
```powershell
flutter run
```

### Mode Server Lokal (Development di Laptop)
Jika ingin menghubungkan aplikasi ke backend Laravel yang berjalan di localhost:
1. Pastikan server Laravel berjalan di laptop:
   ```powershell
   php artisan serve --host=0.0.0.0 --port=8000
   ```
2. Hubungkan HP via USB, lalu forward port ADB:
   ```powershell
   adb reverse tcp:8000 tcp:8000
   ```
3. Jalankan Flutter:
   ```powershell
   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
   ```

### Build APK Debug / Release
```powershell
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```
File APK akan berada di folder `build/app/outputs/flutter-apk/`.
