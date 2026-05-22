import 'dart:math';

/// Kumpulan utilitas Pengolahan Citra Digital (PCD) secara manual
/// Menerapkan prinsip Clean Code dan performa tinggi dalam Dart
class ImageProcessingUtils {
  
  /// Mengubah ukuran citra RGB menggunakan Bilinear Interpolation
  /// [src] adalah citra sumber berdimensi [H][W][C]
  static List<List<List<double>>> bilinearResize(
    List<List<List<double>>> src,
    int srcW,
    int srcH,
    int targetW,
    int targetH,
  ) {
    final output = List.generate(
      targetH,
      (_) => List.generate(targetW, (_) => List.filled(3, 0.0)),
    );

    final double xRatio = (srcW - 1) / targetW;
    final double yRatio = (srcH - 1) / targetH;

    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final double px = xRatio * x;
        final double py = yRatio * y;
        
        final int xL = px.floor();
        final int yL = py.floor();
        final int xH = (xL + 1).clamp(0, srcW - 1);
        final int yH = (yL + 1).clamp(0, srcH - 1);

        final double xWeight = px - xL;
        final double yWeight = py - yL;

        // Ambil nilai piksel pada 4 koordinat terdekat
        final p00 = src[yL][xL];
        final p10 = src[yL][xH];
        final p01 = src[yH][xL];
        final p11 = src[yH][xH];

        // Hitung interpolasi untuk setiap saluran warna (R, G, B)
        for (int c = 0; c < 3; c++) {
          output[y][x][c] = p00[c] * (1 - xWeight) * (1 - yWeight) +
              p10[c] * xWeight * (1 - yWeight) +
              p01[c] * (1 - xWeight) * yWeight +
              p11[c] * xWeight * yWeight;
        }
      }
    }
    return output;
  }

  /// Menyeimbangkan kontras citra RGB dengan Global Histogram Equalization pada kanal kecerahan Y (YCbCr)
  static void equalizeContrast(List<List<List<double>>> img, int w, int h) {
    final List<int> histogram = List.filled(256, 0);
    final List<List<double>> yChannel = List.generate(h, (_) => List.filled(w, 0.0));

    // 1. Ekstrak kanal kecerahan Y (Luminance) dan hitung histogramnya
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final r = img[y][x][0];
        final g = img[y][x][1];
        final b = img[y][x][2];

        // Rumus Luminansi standar ITU-R BT.601
        final double yVal = 0.299 * r + 0.587 * g + 0.114 * b;
        yChannel[y][x] = yVal;
        
        final int intensity = yVal.round().clamp(0, 255);
        histogram[intensity]++;
      }
    }

    // 2. Hitung Cumulative Distribution Function (CDF)
    final List<int> cdf = List.filled(256, 0);
    cdf[0] = histogram[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }

    // 3. Cari nilai CDF minimum yang bukan nol
    int cdfMin = 0;
    for (int i = 0; i < 256; i++) {
      if (cdf[i] > 0) {
        cdfMin = cdf[i];
        break;
      }
    }

    // 4. Petakan intensitas piksel baru berdasarkan CDF
    final int totalPixels = w * h;
    final double denominator = (totalPixels - cdfMin).toDouble();
    if (denominator <= 0) return;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double oldY = yChannel[y][x];
        final int oldYInt = oldY.round().clamp(0, 255);

        // Rumus perataan histogram
        final double newY = ((cdf[oldYInt] - cdfMin) / denominator) * 255.0;
        final double ratio = oldY > 0 ? (newY / oldY) : 0.0;

        // Terapkan perubahan kontras secara proporsional ke R, G, dan B
        img[y][x][0] = (img[y][x][0] * ratio).clamp(0.0, 255.0);
        img[y][x][1] = (img[y][x][1] * ratio).clamp(0.0, 255.0);
        img[y][x][2] = (img[y][x][2] * ratio).clamp(0.0, 255.0);
      }
    }
  }

  /// Menghilangkan noise menggunakan Median Filter berukuran 3x3
  static void applyMedianFilter(List<List<List<double>>> img, int w, int h) {
    // Salin citra asli untuk acuan pemrosesan
    final copy = List.generate(
      h,
      (y) => List.generate(w, (x) => List.from(img[y][x])),
    );

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        for (int c = 0; c < 3; c++) {
          final List<double> values = [];
          
          // Kumpulkan 9 piksel tetangga terdekat
          for (int ky = -1; ky <= 1; ky++) {
            for (int kx = -1; kx <= 1; kx++) {
              values.add(copy[y + ky][x + kx][c]);
            }
          }
          
          // Urutkan nilai piksel
          values.sort();
          
          // Tetapkan nilai median (tengah) ke piksel target
          img[y][x][c] = values[4];
        }
      }
    }
  }

  /// 1. Segmentasi Warna Kulit (Skin Segmentation) berdasarkan ruang warna YCbCr.
  /// Mengisolasi warna kulit agar latar belakang (background) bisa dihilangkan.
  /// Piksel yang bukan kulit akan diubah menjadi hitam [0, 0, 0].
  static void applySkinSegmentation(List<List<List<double>>> img, int w, int h) {
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final r = img[y][x][0];
        final g = img[y][x][1];
        final b = img[y][x][2];

        // Konversi RGB ke YCbCr
        final double yVal = 0.299 * r + 0.587 * g + 0.114 * b;
        final double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

        // Rentang threshold warna kulit standar pada YCbCr
        final bool isSkin = (yVal > 80 && cb > 85 && cb < 135 && cr > 135 && cr < 180);

        if (!isSkin) {
          // Jadikan background hitam (hilangkan)
          img[y][x][0] = 0.0;
          img[y][x][1] = 0.0;
          img[y][x][2] = 0.0;
        }
      }
    }
  }

  /// 2. Mengubah gambar menjadi Grayscale lalu menerapkan Thresholding statis.
  /// Menghasilkan citra hitam-putih pekat (siluet) untuk mempertegas bentuk tangan.
  static void applyGrayscaleAndThreshold(List<List<List<double>>> img, int w, int h, {double threshold = 128.0}) {
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final r = img[y][x][0];
        final g = img[y][x][1];
        final b = img[y][x][2];

        // Grayscale (Luminosity)
        final double gray = 0.299 * r + 0.587 * g + 0.114 * b;

        // Thresholding (Hitam Putih Pekat)
        final double bw = (gray >= threshold) ? 255.0 : 0.0;
        
        img[y][x][0] = bw;
        img[y][x][1] = bw;
        img[y][x][2] = bw;
      }
    }
  }

  /// 3A. Morphological Operation: Erosi (Erosion)
  /// Mengikis piksel putih di batas objek. Berguna menghilangkan noise bercak putih (false positives).
  static void applyErosion(List<List<List<double>>> img, int w, int h) {
    // Kita asumsikan citra sudah hitam-putih (0.0 atau 255.0) dari fungsi Thresholding
    final copy = List.generate(h, (y) => List.generate(w, (x) => img[y][x][0]));

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double minVal = 255.0;
        // Cek kernel 3x3
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            if (copy[y + ky][x + kx] < minVal) {
              minVal = copy[y + ky][x + kx];
            }
          }
        }
        
        // Aplikasikan nilai minimum ke 3 channel warna
        img[y][x][0] = minVal;
        img[y][x][1] = minVal;
        img[y][x][2] = minVal;
      }
    }
  }

  /// 3B. Morphological Operation: Dilasi (Dilation)
  /// Menebalkan piksel putih di batas objek. Berguna menutup lubang kecil pada siluet tangan.
  static void applyDilation(List<List<List<double>>> img, int w, int h) {
    // Kita asumsikan citra sudah hitam-putih (0.0 atau 255.0)
    final copy = List.generate(h, (y) => List.generate(w, (x) => img[y][x][0]));

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double maxVal = 0.0;
        // Cek kernel 3x3
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            if (copy[y + ky][x + kx] > maxVal) {
              maxVal = copy[y + ky][x + kx];
            }
          }
        }
        
        // Aplikasikan nilai maksimum ke 3 channel warna
        img[y][x][0] = maxVal;
        img[y][x][1] = maxVal;
        img[y][x][2] = maxVal;
      }
    }
  }
}
