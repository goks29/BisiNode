class ImageProcessingUtils {
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
}
