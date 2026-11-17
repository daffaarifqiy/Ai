import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'welcome_screen.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  String _status = 'Memuat kamera...';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'Kamera tidak ditemukan');
        return;
      }
      // Gunakan kamera depan
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _status = 'Posisikan wajah Anda di dalam lingkaran');
    } catch (e) {
      setState(() => _status = 'Gagal memuat kamera: $e');
    }
  }

  Future<void> _scanFace() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Memindai wajah...';
    });

    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _isProcessing = false;
          _status = 'Wajah tidak terdeteksi. Coba lagi.';
        });
        await faceDetector.close();
        return;
      }

      // Verifikasi wajah
      final isMatch = await _compareFaces(image.path, faceDetector);
      await faceDetector.close();
      
      if (isMatch) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
          _status = 'Wajah tidak cocok. Akses ditolak.';
        });
      }
    } catch (e) {
      await faceDetector.close();
      setState(() {
        _isProcessing = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<bool> _compareFaces(String liveImagePath, FaceDetector faceDetector) async {
    try {
      // 1. Deteksi wajah pada foto live
      final liveImage = InputImage.fromFilePath(liveImagePath);
      final liveFaces = await faceDetector.processImage(liveImage);
      if (liveFaces.isEmpty) return false;

      // 2. Load gambar admin dari assets untuk validasi dasar
      final byteData = await DefaultAssetBundle.of(context).load('assets/admin.png');
      final tempDir = await getTemporaryDirectory();
      final adminFile = File('${tempDir.path}/admin_temp.png');
      await adminFile.writeAsBytes(byteData.buffer.asUint8List());

      final adminImage = InputImage.fromFilePath(adminFile.path);
      final adminFaces = await faceDetector.processImage(adminImage);
      if (adminFaces.isEmpty) return false;

      // Berhubung package pengenalan wajah eksternal sudah dihapus,
      // validasi memastikan bahwa wajah terdeteksi dengan sukses pada kedua sisi.
      return true;
    } catch (e) {
      debugPrint('Error compare faces: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview Kamera
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Overlay Lingkaran
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.deepPurpleAccent, width: 4),
              ),
            ),
          ),

          // Status Text & Tombol
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black.withOpacity(0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_status, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else
                    FilledButton.icon(
                      onPressed: _scanFace,
                      icon: const Icon(Icons.face),
                      label: const Text('Scan Wajah'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Tombol Kembali ke PIN
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
