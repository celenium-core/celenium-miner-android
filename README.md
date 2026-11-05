# Celenium Android Miner (MVP)

Miner Android untuk Celenium (CEN). Catatan realistis: mining PoW berat di HP
sangat tidak efisien. Untuk itu Android berperan sebagai **pool client ringan**
 yang connect ke stratum bridge, bukan miner berat.

## Arsitektur

Android app --> stratum (TCP) / HTTP API bridge --> celeniumd --> blockchain CEN

## Aturan khusus Android (sesuai spesifikasi)

1. Reward Android maksimal 10% dari reward desktop pada hashrate yang sama
   (dilaksanakan di sisi bridge via penanda worker).
2. 1 alamat IP hanya boleh memegang 1 sesi mining Android aktif
   (rate-limit di bridge; koneksi ganda dari IP sama ditolak).

## Fitur MVP

- Input / QR scan wallet address CEN (`cen69*`)
- Connect ke server bridge (host:port dari settings)
- Tampilkan hashrate, share accepted, estimated reward
- 1 sesi per IP (otomatis diputus bila koneksi ganda terdeteksi)

## Stack

Flutter (Dart), klien TCP/HTTP, ZXing (QR). Tanpa native mining library pada
MVP ini (jujur: pool client).


## Bahasa aplikasi (EN / ID)

Satu APK memuat dua bahasa: **Inggris** dan **Indonesia**. Tidak ada APK
terpisah — bahasa dipilih di dalam app lewat **Profil → Bahasa → Ikuti sistem /
English / Bahasa Indonesia**, atau dari setelan HP (Android 13+:
Setelan → Sistem → Bahasa → Bahasa aplikasi). Pilihan disimpan dan langsung
berlaku tanpa restart.

- "Ikuti sistem" mengikuti bahasa HP. Agar Android 13+ menampilkan pilihan
  bahasa app di Setelan, locale didaftarkan di
  `android/app/src/main/res/xml/locales_config.xml` (dirujuk manifest lewat
  `android:localeConfig`).
- Teks hidup di `lib/l10n/app_en.arb` dan `lib/l10n/app_id.arb`; kode Dart-nya
  di-generate saat build (`flutter gen-l10n`, aturannya di `l10n.yaml`), jadi
  tidak pernah diedit manual.
- Menambah bahasa ketiga: buat `lib/l10n/app_<kode>.arb`, tambahkan kode itu di
  `locales_config.xml`, build ulang. Tidak ada tempat lain yang perlu diubah.
- Fungsi terjemahan dipanggil lewat `l10nOf(context)` (`lib/l10n/l10n.dart`);
  tanpa delegate (mis. widget test yang memasang `MaterialApp` polos) hasilnya
  jatuh ke bahasa Inggris, bukan error.

## Build aplikasi (status 5 Nov 2026)

Source aplikasi Flutter `celenium_miner` ada di folder ini (desktop + Android
satu codebase). APK rilis 5 Nov 2026 sudah memuat AdMob dan dua bahasa:

- `Celenium-Miner-arm64.apk` — sha256 `65005449…93bd` (23,1 MB)
- `Celenium-Miner-armeabi-v7a.apk` — sha256 `f07aaf88…a330` (20,7 MB)
- `Celenium-Miner-x86_64.apk` — sha256 `2c1db276…39d1` (24,6 MB)

Berkasnya ada di `~/celenium-web/apk/` dan salinannya di
`build/app/outputs/flutter-apk/`. Build ulang:

```bash
~/flutter-install/flutter/bin/flutter build apk --release --split-per-abi
```

Periksa isi APK tanpa memasangnya ke HP — memastikan App ID AdMob, kelas SDK,
unit banner live, dan teks dua bahasa benar-benar ikut terpaket:

```bash
python3 tool/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Catatan mesin: `android/gradle.properties` sengaja dipasang `-Xmx3G` (bukan
`-Xmx8G` bawaan template Flutter) karena RAM WSL2 di sini hanya 8 GB. Dengan
8 GB heap, R8 menukar memori ke swap dan satu build bisa makan 45 menit;
dengan 3 GB build selesai ~5 menit.

Koneksi app = HTTP API stratum-bridge. Di HP pakai IP LAN host bridge, contoh
`http://192.168.1.4:3030` (bukan 127.0.0.1). Aturan khusus Android dari
spesifikasi (reward maks 10% dan 1 IP = 1 sesi) ditegakkan di sisi bridge,
bukan di app.
