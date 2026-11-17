import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:face_verification/face_verification.dart';
import 'package:path_provider/path_provider.dart';
import 'welcome_screen.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isInitialized = false;
  String _status = 'Memuat kamera...';

  @override
  void initState() {
    super.initState();
    _initFaceVerification();
    _initCamera();
  }

  Future<void> _initFaceVerification() async {
    try {
      await FaceVerification.instance.init();
      _isInitialized = true;
    } catch (e) {
      setState(() => _status = 'Gagal inisialisasi AI Wajah: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'Kamera tidak ditemukan');
        return;
      }
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
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Memindai wajah...';
    });

    try {
      final image = await _controller!.takePicture();
      
      final isAdminRegistered = await FaceVerification.instance.isFaceRegistered('admin');
      if (!isAdminRegistered) {
        final byteData = await DefaultAssetBundle.of(context).load('assets/admin.png');
        final tempDir = await getTemporaryDirectory();
        final adminFile = File('${tempDir.path}/admin_temp.png');
        await adminFile.writeAsBytes(byteData.buffer.asUint8List());

        await FaceVerification.instance.registerFromImagePath(
          id: 'admin',
          imagePath: adminFile.path,
          imageId: 'profile',
          name: 'Admin',
        );
      }

      final matchId = await FaceVerification.instance.verifyFromImagePath(
        imagePath: image.path,
        threshold: 0.70,
        staffId: 'admin',
      );

      if (matchId == 'admin') {
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
      setState(() {
        _isProcessing = false;
        _status = 'Error: $e';
      });
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
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

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
