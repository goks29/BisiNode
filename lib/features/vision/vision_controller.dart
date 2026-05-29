import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'services/camera_service.dart';
import 'services/ml_vision_service.dart';
import 'models/translation_log.dart';

/// Penghubung utama antara kamera, ML service, dan UI
class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final MlVisionService _mlService = MlVisionService();

  List<BoundingBox> detections = [];
  String assembledWord = "";
  bool isSwitchingModel = false;

  // Sentence Builder state
  String _lastDetectedLabel = "";
  int _consecutiveFrames = 0;
  DateTime? _firstDetectionTime;
  static const _verificationDuration = Duration(milliseconds : 1500);

  bool get isInitialized => _cameraService.isInitialized;
  CameraController? get cameraController => _cameraService.controller;
  bool get isFlashlightOn => _cameraService.isFlashlightOn;
  ModelType get currentModelType => _mlService.currentModelType;
  double get consecutiveProgress {
    if (_firstDetectionTime == null) return 0.0;
    final elapsed = DateTime.now().difference(_firstDetectionTime!);
    return (elapsed.inMilliseconds / _verificationDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  VisionController() {
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  Future<void> _initAll() async {
    await _mlService.loadModel();
    await _cameraService.initialize();
    _startDetection();
    notifyListeners();
  }

  /// Dynamic Model Switching 
  Future<void> switchModel(ModelType type) async {
    if (type == currentModelType || isSwitchingModel) return;
    isSwitchingModel = true;
    detections = [];
    notifyListeners();

    try {
      // Hentikan stream & beri waktu buffer kamera bersih
      if (cameraController != null && cameraController!.value.isStreamingImages) {
        await cameraController!.stopImageStream();
      }
      await Future.delayed(const Duration(milliseconds: 200));

      await _mlService.switchModel(type);
      _resetSentenceState();

      // Aktifkan kembali stream
      _startDetection();
    } catch (e) {
      print("VisionController: switchModel error: $e");
    }

    isSwitchingModel = false;
    notifyListeners();
  }

  void _startDetection() {
    if (cameraController == null || !cameraController!.value.isInitialized) return;
    if (cameraController!.value.isStreamingImages) return;

    cameraController!.startImageStream((CameraImage image) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (isSwitchingModel || _mlService.isProcessing || now - _mlService.lastInferenceTime < 250) return;

      _mlService.isProcessing = true;
      try {
        await Future.delayed(const Duration(milliseconds: 5));
        final isFront = cameraController?.description.lensDirection == CameraLensDirection.front;
        final results = await _mlService.runInference(image, isFront);
        _mlService.lastInferenceTime = DateTime.now().millisecondsSinceEpoch;
        _updateDetections(results, isCameraStream: true);
      } finally {
        _mlService.isProcessing = false;
      }
    });
  }

  void _updateDetections(List<BoundingBox> newDetections, {bool isCameraStream = false}) {
    // Stabilisasi: jangan langsung hapus deteksi lama (anti-flicker)
    if (newDetections.isEmpty && detections.isNotEmpty) return;

    if (isCameraStream && newDetections.isNotEmpty) {
      newDetections.sort((a, b) => b.confidence.compareTo(a.confidence));
      final top = newDetections.first;

      if (top.label.trim().isNotEmpty && top.label == _lastDetectedLabel) {
        _firstDetectionTime ??= DateTime.now();
        _consecutiveFrames++;

        final elapsed = DateTime.now().difference(_firstDetectionTime!);
        if (elapsed >= _verificationDuration) {
          // Tandai sebagai terverifikasi
          newDetections = newDetections.map((d) =>
            d.label == top.label ? d.copyWith(isVerified: true) : d
          ).toList();

          _onLetterVerified(top.label);
          _resetSentenceState();
        }
      } else {
        _lastDetectedLabel = top.label;
        _firstDetectionTime = DateTime.now();
        _consecutiveFrames = 1;
      }
    } else if (isCameraStream) {
      _resetSentenceState();
    }

    detections = newDetections;
    notifyListeners();
  }

  /// Feedback saat huruf/angka terverifikasi
  void _onLetterVerified(String label) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    assembledWord += label;
    _saveToHive(label);
  }

  /// Persistensi ke Hive 
  Future<void> _saveToHive(String letter) async {
    if (!Hive.isBoxOpen('translation_logs')) return;

    final box = Hive.box<TranslationLog>('translation_logs');
    await box.add(TranslationLog(
      text: letter,
      timestamp: DateTime.now(),
      modelType: currentModelType.name,
    ));
  }

  void _resetSentenceState() {
    _lastDetectedLabel = "";
    _consecutiveFrames = 0;
    _firstDetectionTime = null;
  }

  // --- Text Controls ---
  void addSpace() {
    assembledWord += " ";
    notifyListeners();
  }

  void backspace() {
    if (assembledWord.isNotEmpty) {
      assembledWord = assembledWord.substring(0, assembledWord.length - 1);
      notifyListeners();
    }
  }

  void clearText() {
    assembledWord = "";
    _resetSentenceState();
    notifyListeners();
  }

  /// Putar kamera depan ke belakang
  Future<void> flipCamera() async {
    try {
      if (cameraController != null && cameraController!.value.isStreamingImages) {
        await cameraController!.stopImageStream();
      }
      await Future.delayed(const Duration(milliseconds: 150));
      await _cameraService.flipCamera();
      _resetSentenceState();
      detections = [];
      await Future.delayed(const Duration(milliseconds: 200));
      _startDetection();
    } catch (e) {
      print("VisionController: flipCamera error: $e");
    }
    notifyListeners();
  }

  Future<void> toggleFlashlight() => _cameraService.toggleFlashlight();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (cameraController == null || !cameraController!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _cameraService.release();
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      _initAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _mlService.dispose();
    super.dispose();
  }
}
