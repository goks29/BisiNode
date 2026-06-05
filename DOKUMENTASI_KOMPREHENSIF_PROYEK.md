# Dokumentasi Komprehensif Proyek: BISINDO Edge Translator & Logbook App

## 1. Pendahuluan
Proyek ini adalah aplikasi mobile berbasis Flutter yang dirancang untuk membantu komunikasi bagi komunitas tunarungu melalui penerjemah Bahasa Isyarat Indonesia (BISINDO) secara *real-time* di perangkat (Edge AI), sekaligus menyediakan fitur pencatatan kegiatan (Logbook) yang bersifat *offline-first* dengan sinkronisasi otomatis ke cloud.

### Fitur Utama:
- **Penerjemah BISINDO Real-Time**: Deteksi alfabet dan angka BISINDO menggunakan kamera ponsel dengan teknologi TensorFlow Lite.
- **Logbook Offline-First**: Pencatatan kegiatan yang tetap berfungsi tanpa internet, menggunakan Hive untuk penyimpanan lokal dan MongoDB Atlas untuk sinkronisasi cloud.
- **Role-Based Access Control (RBAC)**: Pembagian hak akses (Ketua, Asisten, Anggota) untuk keamanan data.
- **Auto-Sync**: Sinkronisasi data otomatis saat perangkat mendeteksi koneksi internet kembali.
- **Performa Tinggi**: Pemrosesan gambar ML dilakukan di *background thread* (Isolates) untuk menjaga kelancaran UI (60 FPS).

---

## 2. Arsitektur Proyek
Aplikasi ini menggunakan pendekatan **Feature-Based Architecture**, di mana setiap fitur utama memiliki folder tersendiri yang berisi Controller, View, Model, dan Service terkait.

### Struktur Folder Utama:
- `lib/features/vision/`: Logika deteksi ML, streaming kamera, dan post-processing hasil deteksi.
- `lib/features/logbook/`: Manajemen catatan, sinkronisasi Hive-MongoDB, dan editor Markdown.
- `lib/features/auth/`: Sistem login dengan akun hardcoded dan manajemen sesi.
- `lib/services/`: Service global seperti koneksi database (`MongoService`) dan kontrol akses (`AccessControlService`).
- `lib/helpers/`: Utility tambahan seperti sistem logging kustom.
- `assets/models/`: Berisi file model `.tflite` dan label teks untuk alfabet dan angka.

### State Management:
Proyek ini menggunakan kombinasi `ValueNotifier` dan `ChangeNotifier`. Pendekatan ini dipilih karena ringan dan cukup kuat untuk menangani perubahan state tanpa memerlukan library pihak ketiga yang berat seperti GetX atau Bloc, sehingga menjaga jejak memori tetap kecil.

---

## 3. Detail Teknis Fitur Vision (AI/ML)
Fitur ini adalah inti dari aplikasi, yang memungkinkan penerjemahan bahasa isyarat.

### 3.1 Model & Pipeline ML
Aplikasi menggunakan model **SSD MobileNet v2** yang telah dikuantisasi untuk dijalankan di perangkat mobile melalui `tflite_flutter`.

- **Model Alfabet**: `abjad_v2.tflite` (26 kelas alfabet A-Z).
- **Model Angka**: `angka_v2_fix.tflite` (10 kelas angka 0-9).

### 3.2 Preprocessing Gambar (Isolates)
Untuk mencegah *UI jank* (patah-patah), proses konversi gambar dari stream kamera (format YUV420) ke format yang dimengerti model (RGB + Normalisasi) dilakukan di dalam **Dart Isolate**.
1. **Rotation**: Menyesuaikan orientasi gambar kamera (biasanya 90 derajat di Android).
2. **Center Crop**: Memotong gambar menjadi kotak (1:1) agar objek tidak terdistorsi saat di-resize ke ukuran input model (biasanya 300x300 atau 320x320).
3. **Normalization**: Mengubah nilai pixel 0-255 menjadi -1.0 hingga 1.0 (untuk model float) atau tetap 0-255 (untuk model quantized).

### 3.3 Logika Verifikasi (Consistency Logic)
Aplikasi tidak langsung menerima hasil deteksi sekali lewat. Terdapat algoritma verifikasi di `VisionController`:
- Sebuah huruf harus terdeteksi secara konsisten selama **2 detik** (ambang batas waktu bisa diatur di `.env`) sebelum dianggap valid dan dimasukkan ke dalam kalimat hasil terjemahan.
- Hal ini mengurangi kesalahan deteksi akibat gerakan tangan yang cepat atau *noise* pada gambar.

### 3.4 ROI Filtering
Aplikasi menerapkan **ROI (Region of Interest) Top Cutoff**. Deteksi yang berada di area atas frame (biasanya area wajah pengguna) akan diabaikan. Hal ini membantu model fokus pada tangan dan mengurangi *false positive* dari wajah.

---

## 4. Sistem Logbook & Sinkronisasi Database
Aplikasi ini menerapkan strategi **Offline-First**.

### 4.1 Penyimpanan Lokal (Hive)
Semua catatan baru disimpan terlebih dahulu ke **Hive**, database NoSQL lokal yang sangat cepat. Ini memastikan pengguna dapat menulis catatan meskipun di area tanpa sinyal.

### 4.2 Sinkronisasi Cloud (MongoDB Atlas)
Saat ada koneksi internet:
1. `LogController` akan mencoba mengirim data ke MongoDB Atlas.
2. Jika berhasil, flag `isSynced` pada model diubah menjadi `true`.
3. Jika gagal, data tetap di lokal dan ditandai belum sinkron.
4. **Auto-Sync Listener**: Menggunakan `connectivity_plus` untuk mendeteksi kembalinya koneksi dan secara otomatis mengirim semua catatan yang belum tersinkron.

### 4.3 Sharing & Privacy
- **Shared Logs**: Semua anggota tim dapat melihat catatan yang ditandai sebagai `isPublic`.
- **Ownership**: Hanya pembuat catatan (berdasarkan `authorId`) yang memiliki hak untuk mengubah atau menghapus catatan tersebut.

---

## 5. Keamanan & Role-Based Access Control (RBAC)
Meskipun saat ini menggunakan akun hardcoded, sistem RBAC sudah terimplementasi secara modular di `AccessControlService`.

### Peran (Roles):
1. **Ketua**: Hak akses penuh (Create, Read, Update, Delete semua data).
2. **Asisten**: Dapat membaca data dan melakukan update, namun tidak bisa menghapus secara sembarangan.
3. **Anggota**: Dapat membuat dan membaca data. Hanya bisa mengubah/menghapus data milik sendiri.

### Mekanisme Login:
- Terdapat sistem **Lockout Mechanism**: Setelah 3 kali gagal login, tombol login akan terkunci selama 10 detik untuk mencegah serangan brute-force sederhana.

---

## 6. Konfigurasi Sistem (.env)
Aplikasi sangat bergantung pada file `.env` untuk konfigurasi tanpa perlu mengubah kode sumber:
- `MONGODB_URI`: URL koneksi ke MongoDB Atlas.
- `CONFIDENCE_THRESHOLD`: Ambang batas minimal deteksi ML (default 0.65).
- `VERIFICATION_DURATION_MS`: Durasi verifikasi tanda isyarat (default 2000ms).
- `ROI_TOP_CUTOFF`: Batas area atas yang diabaikan (default 0.25).
- `MODEL_ABJAD_PATH` & `MODEL_ANGKA_PATH`: Jalur aset model TFLite.

---

## 7. Panduan Pengembangan (Developer Guide)

### Persiapan Lingkungan:
1. Pastikan Flutter SDK terpasang (versi ^3.10.8).
2. Buat file `.env` di root project dengan mengikuti template yang ada.
3. Jalankan `flutter pub get`.
4. Untuk pengembangan model AI, letakkan file `.tflite` baru di `assets/models/` dan update jalur di `.env`.

### Alur Penambahan Fitur Baru:
1. Buat folder baru di `lib/features/`.
2. Gunakan `ValueNotifier` untuk reaktivitas UI.
3. Jika memerlukan penyimpanan data, buat model dengan adapter Hive (`build_runner`).
4. Daftarkan adapter di `lib/main.dart`.

---

## 8. Analisis Kode Penting

### `MlVisionService.dart`
Mengelola siklus hidup interpreter TFLite. Menggunakan `IsolateInterpreter` dari library `tflite_flutter` untuk menjalankan inferensi secara paralel. Fungsi `_parseOutput` mengimplementasikan logika parsing tensor SSD yang mendeteksi kotak pembatas (bounding boxes), kelas objek, dan skor kepercayaan.

### `LogController.dart`
Jantung dari fitur Logbook. Mengelola transisi data antara Hive dan MongoDB. Memiliki listener konektivitas yang memicu fungsi `_syncOfflineLogs()` saat internet tersedia.

### `MongoService.dart`
Implementasi Singleton untuk koneksi database. Menyediakan metode CRUD yang memiliki logika *auto-reconnect* jika koneksi terputus di tengah jalan.

---

## 9. Kesimpulan
Aplikasi ini menggabungkan kecanggihan **Edge AI** dengan keandalan **Cloud Synchronization**. Arsitektur yang modular dan penggunaan teknologi yang efisien (Hive, Isolates, TFLite) menjadikannya solusi yang performan untuk digunakan di lapangan, bahkan dengan keterbatasan perangkat dan koneksi internet.

---
*Dokumentasi ini dibuat secara otomatis untuk memberikan pemahaman menyeluruh terhadap struktur dan logika internal proyek.*
