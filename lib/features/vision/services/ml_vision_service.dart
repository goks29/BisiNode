import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum ModelType { alphabet, numbers }

/// Data model deteksi bounding box
class BoundingBox {
  final ui.Rect rect;
  final String label;
  final double confidence;
  final bool isVerified;

  BoundingBox({
    required this.rect,
    required this.label,
    required this.confidence,
    this.isVerified = false,
  });

  BoundingBox copyWith({bool? isVerified}) => BoundingBox(
    rect: rect,
    label: label,
    confidence: confidence,
    isVerified: isVerified ?? this.isVerified,
  );
}

/// Service inferensi SSD MobileNet v2 untuk deteksi bahasa isyarat
class MlVisionService {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = [];
  ModelType _currentModelType = ModelType.alphabet;
  bool? _isQuantizedModel;
  bool isProcessing = false;
  int lastInferenceTime = 0;

  ModelType get currentModelType => _currentModelType;
  List<String> get labels => _labels;

  /// Threshold dari .env (Single Source of Truth)
  double get confidenceThreshold =>
      double.tryParse(dotenv.env['CONFIDENCE_THRESHOLD'] ?? '0.65') ?? 0.65;

  /// Batas atas ROI: deteksi di atas garis ini diabaikan (area wajah)
  double get roiTopCutoff =>
      double.tryParse(dotenv.env['ROI_TOP_CUTOFF'] ?? '0.25') ?? 0.25;

  /// Jalur model & label dari .env berdasarkan tipe
  Map<String, String> _pathsForType(ModelType type) {
    switch (type) {
      case ModelType.alphabet:
        return {
          'model': dotenv.env['MODEL_ABJAD_PATH'] ?? 'assets/models/abjad_v2.tflite',
          'label': dotenv.env['LABEL_ABJAD_PATH'] ?? 'assets/models/labels_abjad.txt',
        };
      case ModelType.numbers:
        return {
          'model': dotenv.env['MODEL_ANGKA_PATH'] ?? 'assets/models/angka_v2_fix.tflite',
          'label': dotenv.env['LABEL_ANGKA_PATH'] ?? 'assets/models/labels_angka.txt',
        };

    }
  }

  Future<void> loadModel([ModelType? type]) async {
    type ??= _currentModelType;
    final paths = _pathsForType(type);

    // Tutup IsolateInterpreter TERLEBIH DAHULU sebelum interpreter
    await _safeCloseInterpreters();

    _isQuantizedModel = null;

    _interpreter = await Interpreter.fromAsset(paths['model']!);
    try {
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );
    } catch (_) {
      _isolateInterpreter = null;
    }

    final labelData = await rootBundle.loadString(paths['label']!);
    _labels = labelData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    _currentModelType = type;
  }

  /// Tutup interpreter secara aman (cegah native crash)
  Future<void> _safeCloseInterpreters() async {
    // Isolate harus ditutup sebelum Interpreter dasar
    if (_isolateInterpreter != null) {
      try {
        await _isolateInterpreter!.close();
      } catch (_) {}
      _isolateInterpreter = null;
    }
    if (_interpreter != null) {
      try {
        _interpreter!.close();
      } catch (_) {}
      _interpreter = null;
    }
  }

  /// Thread-Safe Model Switching
  Future<void> switchModel(ModelType type) async {
    if (type == _currentModelType) return;
    
    // Tunggu hingga inferensi terakhir benar-benar selesai sebelum menutup interpreter
    while (isProcessing) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    
    isProcessing = true;
    await loadModel(type);
    isProcessing = false;
  }

  /// Inferensi pada CameraImage stream
  Future<List<BoundingBox>> runInference(CameraImage image, bool isFrontCamera) async {
    if (_interpreter == null) return [];

    final inputTensor = _interpreter!.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final inputH = inputShape[1];
    final inputW = inputShape[2];
    _isQuantizedModel ??= inputTensor.type == TensorType.uint8;

    final input = await _preprocessCamera(image, inputH, inputW, _isQuantizedModel!, isFrontCamera);
    if (input == null) return [];

    return await _executeAndParse(input);
  }

  /// Inferensi pada gambar statis
  Future<List<BoundingBox>> runInferenceOnImage(Uint8List imageBytes) async {
    if (_interpreter == null) return [];

    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final inputTensor = _interpreter!.getInputTensor(0);
    final shape = inputTensor.shape;
    final targetH = shape[1];
    final targetW = shape[2];
    _isQuantizedModel ??= inputTensor.type == TensorType.uint8;

    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final pixels = byteData.buffer.asUint8List();
    final srcW = uiImage.width;
    final srcH = uiImage.height;

    final tensor = _createEmptyTensor(targetH, targetW, _isQuantizedModel!);

    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final srcX = ((x * srcW) ~/ targetW).clamp(0, srcW - 1);
        final srcY = ((y * srcH) ~/ targetH).clamp(0, srcH - 1);
        final idx = (srcY * srcW + srcX) * 4;
        final r = pixels[idx].toDouble();
        final g = pixels[idx + 1].toDouble();
        final b = pixels[idx + 2].toDouble();

        if (_isQuantizedModel!) {
          tensor[0][y][x][0] = r.toInt();
          tensor[0][y][x][1] = g.toInt();
          tensor[0][y][x][2] = b.toInt();
        } else {
          tensor[0][y][x][0] = (r - 127.5) / 127.5;
          tensor[0][y][x][1] = (g - 127.5) / 127.5;
          tensor[0][y][x][2] = (b - 127.5) / 127.5;
        }
      }
    }

    return await _executeAndParse(tensor);
  }

  List _createEmptyTensor(int h, int w, bool isQuantized) {
    return List.generate(
      1,
      (_) => List.generate(
        h,
        (_) => List.generate(w, (_) => List.filled(3, isQuantized ? 0 : 0.0)),
      ),
    );
  }

  Future<List<BoundingBox>> _executeAndParse(Object input) async {
    if (_interpreter == null) return [];

    final outTensors = _interpreter!.getOutputTensors();
    final Map<int, Object> outputBuffers = {};

    for (var i = 0; i < outTensors.length; i++) {
      final shape = outTensors[i].shape;
      int numElements = 1;
      for (var dim in shape) numElements *= dim;
      outputBuffers[i] = outTensors[i].type == TensorType.uint8
          ? List.filled(numElements, 0).reshape(shape)
          : List.filled(numElements, 0.0).reshape(shape);
    }

    try {
      if (_isolateInterpreter != null) {
        await _isolateInterpreter!.runForMultipleInputs([input], outputBuffers);
      } else {
        _interpreter!.runForMultipleInputs([input], outputBuffers);
      }
    } catch (e) {
      print("ML_VISION: Inference error: $e");
      return [];
    }

    return _parseOutput(outTensors, outputBuffers);
  }

  /// Parse output tensor SSD MobileNet v2 (TFLite_Detection_PostProcess)
  ///
  /// Model output order (fixed by TFLite post-processing):
  ///   T[0] = detection_boxes  [1, N, 4]  atau [1, N] (boxes, normalized 0-1)
  ///   T[1] = detection_classes [1, N]
  ///   T[2] = detection_scores  [1, N]
  ///   T[3] = num_detections    [1]
  ///
  /// NAMUN shape bisa bervariasi, jadi kita identifikasi berdasarkan dimensi.
  List<BoundingBox> _parseOutput(List<Tensor> outTensors, Map<int, Object> buffers) {
    final List<BoundingBox> detections = [];
    final threshold = confidenceThreshold;

    try {
      // Identifikasi tensor berdasarkan shape yang unik
      int boxesIdx = -1;
      int numIdx = -1;
      List<int> flatTensors = []; // Tensor [1, N] → classes atau scores

      for (int i = 0; i < outTensors.length; i++) {
        final shape = outTensors[i].shape;
        if (shape.length == 3 && shape.last == 4) {
          boxesIdx = i; // [1, N, 4]
        } else if (shape.length == 1) {
          numIdx = i; // [1] → num_detections
        } else if (shape.length == 2) {
          flatTensors.add(i); // [1, N] → classes atau scores
        }
      }

      if (boxesIdx == -1 || flatTensors.length < 2) return [];

      // Baca num_detections
      int maxDetections = 10;
      if (numIdx != -1) {
        final numList = buffers[numIdx] as List;
        maxDetections = (numList[0] as num).toInt().clamp(0, 100);
      }
      if (maxDetections == 0) return [];

      // Baca boxes (normalized 0.0 - 1.0)
      final boxesOutput = buffers[boxesIdx] as List;
      final boxesRaw = boxesOutput[0] as List; // batch dim → [N, 4]

      // Tentukan mana scores, mana classes dari 2 tensor flat [1, N]
      // Scores biasanya float dengan pecahan, classes integer (0, 1, 2...)
      int scoresIdx = flatTensors[0];
      int classesIdx = flatTensors[1];

      // Baca data mentah kedua tensor
      final rawA = (buffers[flatTensors[0]] as List)[0] as List;
      final rawB = (buffers[flatTensors[1]] as List)[0] as List;

      // Heuristik: scores memiliki nilai antara 0-1 dengan pecahan desimal
      // classes memiliki nilai integer (0.0, 1.0, 2.0, ...)
      final maxA = rawA.fold<double>(0.0, (prev, e) => (e as num).toDouble().abs() > prev ? (e as num).toDouble().abs() : prev);
      final maxB = rawB.fold<double>(0.0, (prev, e) => (e as num).toDouble().abs() > prev ? (e as num).toDouble().abs() : prev);

      // Tensor dengan nilai maximum lebih kecil (0-1 range) adalah scores
      // Tensor dengan nilai integer lebih besar (0, 1, 2, ..., 25) adalah classes
      if (maxA > 1.0 && maxB <= 1.0) {
        classesIdx = flatTensors[0];
        scoresIdx = flatTensors[1];
      } else if (maxB > 1.0 && maxA <= 1.0) {
        classesIdx = flatTensors[1];
        scoresIdx = flatTensors[0];
      } else {
        // Keduanya <=1.0 atau keduanya >1.0 → fallback: cek pecahan desimal
        bool aHasFractions = rawA.any((e) {
          final v = (e as num).toDouble();
          return v != v.truncateToDouble() && v > 0.001;
        });
        bool bHasFractions = rawB.any((e) {
          final v = (e as num).toDouble();
          return v != v.truncateToDouble() && v > 0.001;
        });

        if (aHasFractions && !bHasFractions) {
          scoresIdx = flatTensors[0];
          classesIdx = flatTensors[1];
        } else if (bHasFractions && !aHasFractions) {
          scoresIdx = flatTensors[1];
          classesIdx = flatTensors[0];
        }
        // Kalau keduanya sama, tetap default
      }

      final scoresRaw = (buffers[scoresIdx] as List)[0] as List;
      final classesRaw = (buffers[classesIdx] as List)[0] as List;

      double maxScore = 0.0;
      final count = maxDetections.clamp(0, scoresRaw.length);
      final topCutoff = roiTopCutoff;

      for (int i = 0; i < count; i++) {
        final score = (scoresRaw[i] as num).toDouble();
        if (score > maxScore) maxScore = score;
        if (score < threshold) continue;

        // SSD format: [ymin, xmin, ymax, xmax] (normalized 0-1)
        final box = boxesRaw[i] as List;
        final ymin = (box[0] as num).toDouble();
        final xmin = (box[1] as num).toDouble();
        final ymax = (box[2] as num).toDouble();
        final xmax = (box[3] as num).toDouble();

        // Filter 1: ROI — abaikan deteksi di area atas (wajah)
        final boxCenterY = (ymin + ymax) / 2;
        if (boxCenterY < topCutoff) continue;

        // Filter 2: abaikan box terlalu besar (wajah > 40% frame)
        final boxArea = (xmax - xmin) * (ymax - ymin);
        if (boxArea > 0.4) continue;

        final classIndex = (classesRaw[i] as num).toInt();
        final label = (classIndex >= 0 && classIndex < _labels.length)
            ? _labels[classIndex]
            : "Class_$classIndex";

        detections.add(BoundingBox(
          rect: ui.Rect.fromLTRB(xmin, ymin, xmax, ymax),
          label: label,
          confidence: score,
        ));
      }
      
      print("ML_DEBUG: Max Score = $maxScore, Detections = ${detections.length}");
    } catch (e) {
      print("ML_VISION: Parse error: $e");
    }

    return detections;
  }

  /// YUV420 → RGB → Center Crop → Tensor (Background Isolate)
  Future<Object?> _preprocessCamera(
    CameraImage image,
    int targetH,
    int targetW,
    bool isQuantized,
    bool isFrontCamera,
  ) async {
    try {
      final srcW = image.width;
      final srcH = image.height;
      final hasUV = image.planes.length >= 3;

      final yPlane = image.planes[0].bytes;
      final uPlane = hasUV ? image.planes[1].bytes : Uint8List(0);
      final vPlane = hasUV ? image.planes[2].bytes : Uint8List(0);
      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = hasUV ? image.planes[1].bytesPerRow : 0;
      final uvPixelStride = hasUV ? (image.planes[1].bytesPerPixel ?? 1) : 1;

      return await Isolate.run(() {
        final tensor = List.generate(
          1,
          (_) => List.generate(
            targetH,
            (_) => List.generate(targetW, (_) => List.filled(3, isQuantized ? 0 : 0.0)),
          ),
        );

        // Center-crop untuk aspect ratio 1:1
        final rotate90 = srcW > srcH;
        final int cropSize = srcW < srcH ? srcW : srcH;
        final int cropStartX = (srcW - cropSize) ~/ 2;
        final int cropStartY = (srcH - cropSize) ~/ 2;

        // Pre-compute coordinate mapping
        final mapYtoSrcX = List.filled(targetH, 0);
        final mapXtoSrcY = List.filled(targetW, 0);
        final mapXtoSrcX = List.filled(targetW, 0);
        final mapYtoSrcY = List.filled(targetH, 0);

        if (rotate90) {
          if (isFrontCamera) {
            for (int y = 0; y < targetH; y++) mapYtoSrcX[y] = cropStartX + ((targetH - 1 - y) * cropSize) ~/ targetH;
            for (int x = 0; x < targetW; x++) mapXtoSrcY[x] = cropStartY + ((targetW - 1 - x) * cropSize) ~/ targetW;
          } else {
            for (int y = 0; y < targetH; y++) mapYtoSrcX[y] = cropStartX + (y * cropSize) ~/ targetH;
            for (int x = 0; x < targetW; x++) mapXtoSrcY[x] = cropStartY + ((targetW - 1 - x) * cropSize) ~/ targetW;
          }
        } else {
          if (isFrontCamera) {
            for (int x = 0; x < targetW; x++) mapXtoSrcX[x] = cropStartX + ((targetW - 1 - x) * cropSize) ~/ targetW;
            for (int y = 0; y < targetH; y++) mapYtoSrcY[y] = cropStartY + (y * cropSize) ~/ targetH;
          } else {
            for (int x = 0; x < targetW; x++) mapXtoSrcX[x] = cropStartX + (x * cropSize) ~/ targetW;
            for (int y = 0; y < targetH; y++) mapYtoSrcY[y] = cropStartY + (y * cropSize) ~/ targetH;
          }
        }

        for (int y = 0; y < targetH; y++) {
          for (int x = 0; x < targetW; x++) {
            final int srcX;
            final int srcY;

            if (rotate90) {
              srcX = mapYtoSrcX[y];
              srcY = mapXtoSrcY[x];
            } else {
              srcX = mapXtoSrcX[x];
              srcY = mapYtoSrcY[y];
            }

            final yIndex = srcY * yRowStride + srcX;
            final yVal = yPlane[yIndex].toDouble();

            double r, g, b;
            if (hasUV) {
              final uvIndex = (srcY ~/ 2) * uvRowStride + (srcX ~/ 2) * uvPixelStride;
              final uVal = uPlane[uvIndex].toDouble() - 128.0;
              final vVal = vPlane[uvIndex].toDouble() - 128.0;
              r = (yVal + 1.402 * vVal).clamp(0, 255);
              g = (yVal - 0.344136 * uVal - 0.714136 * vVal).clamp(0, 255);
              b = (yVal + 1.772 * uVal).clamp(0, 255);
            } else {
              r = g = b = yVal;
            }

            if (isQuantized) {
              tensor[0][y][x][0] = r.toInt();
              tensor[0][y][x][1] = g.toInt();
              tensor[0][y][x][2] = b.toInt();
            } else {
              // SSD MobileNet v2 float model: normalisasi -1.0 ke 1.0
              tensor[0][y][x][0] = (r - 127.5) / 127.5;
              tensor[0][y][x][1] = (g - 127.5) / 127.5;
              tensor[0][y][x][2] = (b - 127.5) / 127.5;
            }
          }
        }

        return tensor;
      });
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _isolateInterpreter = null;
    _interpreter?.close();
  }
}
