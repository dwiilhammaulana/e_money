# Dompet Jajan

| Info | Detail |
| --- | --- |
| Nama | Dwi Ilham Maulana |
| Kelas | TISE23M |
| Mata Kuliah | KB1154 - Aplikasi Mobile Lanjutan |
| Tugas | UAS - Integrasi E-Commerce dengan E-Money menggunakan Deep Link |

## Deskripsi

Dompet Jajan adalah aplikasi e-money berbasis Flutter yang digunakan untuk login, melihat saldo, top up, transfer, dan memproses pembayaran dari aplikasi merchant melalui deep link.

Aplikasi ini menerima payment request dari E-Commerce menggunakan skema `dompetkampus://pay`, menampilkan detail transaksi, meminta PIN dan 2FA, lalu memproses pembayaran melalui backend e-money.

## Fitur Utama

- Register dan login menggunakan Firebase Authentication.
- Integrasi backend Golang untuk akun, saldo, transaksi, pembayaran, dan 2FA.
- Dashboard saldo pengguna.
- Top up, transfer, dan pembayaran.
- Deep link pembayaran dari aplikasi merchant.
- Verifikasi PIN dan 2FA sebelum transaksi.
- Dukungan metode 2FA seperti email OTP, TOTP, dan notifikasi Firebase sesuai konfigurasi akun.
- Tema aplikasi bernuansa ungu seperti e-wallet.

## Arsitektur Singkat

Struktur kode menggunakan pendekatan layered architecture.

```text
lib/
|-- main.dart
|-- firebase_options.dart
|-- core/
|   |-- constants/
|   |-- network/
|   |-- router/
|   |-- services/
|   `-- theme/
|-- data/
|   |-- datasources/
|   |-- models/
|   `-- repositories/
|-- domain/
|   |-- entities/
|   |-- repositories/
|   `-- usecases/
|-- injection/
`-- presentation/
    |-- blocs/
    |-- pages/
    `-- widgets/
```

| Bagian | Fungsi |
| --- | --- |
| `core` | Konfigurasi global, router, API client, theme, dan deep link service. |
| `data` | Implementasi datasource, model response, dan repository. |
| `domain` | Kontrak repository, entity, dan use case. |
| `injection` | Dependency injection menggunakan `get_it`. |
| `presentation` | UI, halaman, widget, dan state management `flutter_bloc`. |

## Konfigurasi Backend

Backend E-Money berjalan pada port `8080`.

```text
Base URL Flutter: http://127.0.0.1:8080
Folder backend: ../be-emoney
```

Jika menjalankan aplikasi di HP Android fisik lewat USB, aktifkan reverse port:

```powershell
adb reverse tcp:8080 tcp:8080
```

Backend membutuhkan service pendukung sesuai panduan, seperti MySQL/XAMPP dan Redis di Docker.

## Cara Menjalankan

1. Jalankan Redis dan database sesuai konfigurasi backend.
2. Jalankan backend E-Money.

```powershell
cd "D:\kulyah\smt 6\mobile app lanjutan\12\inside dosen\be-emoney"
go run .
```

3. Jalankan aplikasi Flutter.

```powershell
cd "D:\kulyah\smt 6\mobile app lanjutan\12\inside dosen\dompet_kampus_global"
flutter pub get
adb reverse tcp:8080 tcp:8080
flutter run
```

4. Pastikan endpoint health dapat diakses dari device.

```text
http://127.0.0.1:8080/v1/health
```

## Deep Link Payment

### Deep link masuk dari E-Commerce

```text
dompetkampus://pay?merchant_id=MCH_E_COMMERCE&merchant_name=e_commerce&amount=75000&description=Order%20%231&reference=INV-1&callback=pasarmalam%3A%2F%2Fpayment-callback
```

Parameter yang dibaca aplikasi:

| Parameter | Fungsi |
| --- | --- |
| `merchant_id` | ID merchant pengirim transaksi. |
| `merchant_name` | Nama merchant yang ditampilkan ke user. |
| `amount` | Nominal pembayaran. |
| `description` | Deskripsi transaksi. |
| `reference` | Nomor referensi order dari merchant. |
| `callback` | Deep link tujuan untuk mengirim hasil pembayaran kembali ke merchant. |

### Intent filter Android

Aplikasi dikonfigurasi untuk menerima:

```text
dompetkampus://pay
https://dompetkampus.app/pay
```

## Test Manual

1. Login ke Dompet Jajan.
2. Pastikan saldo akun mencukupi.
3. Jalankan deep link pembayaran dari ADB.

```powershell
adb shell "am start -a android.intent.action.VIEW -d 'dompetkampus://pay?merchant_id=MCH_E_COMMERCE&merchant_name=e_commerce&amount=75000&description=Order%20%231&reference=INV-1&callback=pasarmalam%3A%2F%2Fpayment-callback'"
```

4. Pastikan halaman payment request terbuka.
5. Masukkan PIN.
6. Selesaikan 2FA sesuai metode akun.
7. Pastikan transaksi berhasil dan saldo berkurang.

## Dependensi Utama

| Dependency | Fungsi |
| --- | --- |
| `flutter_bloc` | State management. |
| `get_it` | Dependency injection. |
| `go_router` | Routing aplikasi. |
| `dio` | HTTP client ke backend. |
| `firebase_core`, `firebase_auth`, `firebase_messaging` | Firebase auth dan notifikasi. |
| `google_sign_in` | Login Google. |
| `flutter_secure_storage` | Penyimpanan token dan session. |
| `app_links` | Deep link payment. |

## Build APK

```powershell
flutter build apk --debug
```

atau untuk release:

```powershell
flutter build apk --release
```

## Dokumentasi Pengumpulan

- Screenshot aplikasi: tambahkan pada bagian ini sebelum dikumpulkan.
- Link video presentasi: https://youtu.be/D5u48pCRPgg
- APK: lampirkan file hasil build dari folder `build/app/outputs/flutter-apk/`.
