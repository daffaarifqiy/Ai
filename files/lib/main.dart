import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mengatur warna status bar agar menyatu dengan tema gelap
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Inisialisasi database lokal (Hive)
  await Hive.initFlutter();
  await Hive.openBox('chat_sessions');
  await Hive.openBox('chat_messages');

  runApp(const XdfaaaApp());
}

class XdfaaaApp extends StatelessWidget {
  const XdfaaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xdfaaa ai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7C4DFF),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      // Aplikasi dimulai dari layar kunci (Lock Screen)
      home: const LockScreen(), 
    );
  }
}
