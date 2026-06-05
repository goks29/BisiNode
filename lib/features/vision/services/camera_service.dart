import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Mengelola inisialisasi & hardware kamera (SRP)
class CameraService extends ChangeNotifier {
  CameraController? controller;
  List<CameraDescription> _allCameras = [];

  /// Hanya simpan kamera utama per arah (bukan ultra-wide)
  List<CameraDescription> _filteredCameras = [];
  int _currentCameraIndex = 0;
  bool isInitialized = false;
  bool isFlashlightOn = false;
  String? errorMessage;

  bool get isFrontCamera =>
      controller?.description.lensDirection == CameraLensDirection.front;

  Future<void> initialize() async {
    try {
      _allCameras = await availableCameras();
      if (_allCameras.isEmpty) {
        errorMessage = "Tidak ada kamera terdeteksi.";
        notifyListeners();
        return;
      }

      // Filter: ambil hanya kamera pertama per arah 
      _filteredCameras = _filterMainCameras(_allCameras);

      // Prioritaskan kamera depan untuk BISINDO
      _currentCameraIndex = _filteredCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_currentCameraIndex == -1) _currentCameraIndex = 0;

      await _initController(_filteredCameras[_currentCameraIndex]);
    } catch (e) {
      errorMessage = "Gagal inisialisasi kamera: $e";
    }
    notifyListeners();
  }

  /// Ambil satu kamera utama per arah lensa 
  List<CameraDescription> _filterMainCameras(List<CameraDescription> cameras) {
    final Map<CameraLensDirection, CameraDescription> mainCameras = {};
    for (final cam in cameras) {
      // Kamera pertama yang ditemukan per arah = kamera utama (bukan ultra-wide)
      mainCameras.putIfAbsent(cam.lensDirection, () => cam);
    }
    return mainCameras.values.toList();
  }

  Future<void> _initController(CameraDescription camera) async {
    controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller!.initialize();
    isInitialized = true;
    isFlashlightOn = false;
    errorMessage = null;
  }

  /// Putar kamera depan ↔ belakang
  Future<void> flipCamera() async {
    if (_filteredCameras.length < 2) return;

    // Dispose controller lama secara aman
    if (controller != null) {
      try {
        if (controller!.value.isStreamingImages) {
          await controller!.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller!.dispose();
      } catch (_) {}
      controller = null;
      isInitialized = false;
    }

    _currentCameraIndex = (_currentCameraIndex + 1) % _filteredCameras.length;

    try {
      await _initController(_filteredCameras[_currentCameraIndex]);
    } catch (e) {
      errorMessage = "Gagal flip kamera: $e";
    }
    notifyListeners();
  }

  Future<void> toggleFlashlight() async {
    if (controller == null || !controller!.value.isInitialized) return;
    isFlashlightOn = !isFlashlightOn;
    try {
      await controller!.setFlashMode(
        isFlashlightOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      errorMessage = "Gagal toggle flashlight: $e";
    }
    notifyListeners();
  }

  void release() {
    try {
      if (controller != null && controller!.value.isStreamingImages) {
        controller!.stopImageStream();
      }
    } catch (_) {}
    controller?.dispose();
    controller = null;
    isInitialized = false;
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }
}
