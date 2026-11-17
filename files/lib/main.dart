import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Langsung jalankan aplikasi tanpa inisialisasi berat
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
      ),
      home: const LockScreen(), 
    );
  }
}
