import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/landing_pages.dart';
import 'pages/beranda_pages.dart'; 
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/verify_email_page.dart';
import 'firebase_options.dart'; // Hasil dari flutterfire CLI

    final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RambuIDApp());
}

class RambuIDApp extends StatelessWidget {
  const RambuIDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RambuID',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/verify-email': (context) => const VerifyEmailPage(),
        '/home': (context) => const BerandaPage(),
      },
      theme: ThemeData(
        fontFamily: GoogleFonts.oswald().fontFamily,
      ),
    );
  }
}
