import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'face_login_screen.dart';
import 'welcome_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  bool _isError = false;
  bool _isLoading = false;
  bool _showPinInput = false;

  void _checkPin() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final correctPin = await SettingsService.getPassword();
      if (_pinCtrl.text == correctPin) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        }
      } else {
        setState(() => _isError = true);
        _pinCtrl.clear();
      }
    } catch (e) {
      setState(() => _isError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/ai.jpg.png', 
                  width: 100, height: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.lock, size: 100, color: Colors.deepPurpleAccent),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Login xdfaaa ai', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              // Opsi 1: Face Scan (Utama)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceLoginScreen()));
                  },
                  icon: const Icon(Icons.face),
                  label: const Text('Login dengan Wajah'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              // Opsi 2: PIN
              if (!_showPinInput)
                TextButton(
                  onPressed: () => setState(() => _showPinInput = true),
                  child: const Text('Gunakan PIN', style: TextStyle(color: Colors.white54)),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8),
                        decoration: InputDecoration(
                          counterText: "",
                          errorText: _isError ? 'PIN Salah' : null,
                          border: const OutlineInputBorder(),
                          hintText: '******',
                        ),
                        onSubmitted: (_) => _isLoading ? null : _checkPin(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: _checkPin,
                            child: const Text('Buka dengan PIN'),
                          ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
