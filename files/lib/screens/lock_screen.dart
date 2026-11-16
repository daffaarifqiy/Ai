import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'welcome_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  bool _isError = false;

  void _checkPin() async {
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
              const Icon(Icons.lock, size: 64, color: Colors.deepPurpleAccent),
              const SizedBox(height: 24),
              const Text('Masukkan PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
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
                  ),
                  onSubmitted: (_) => _checkPin(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _checkPin,
                child: const Text('Buka Aplikasi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
