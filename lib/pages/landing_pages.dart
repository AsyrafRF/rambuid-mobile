import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _fadeText;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    _fadeText = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 1000), () {
      _textController.forward();
    });

    // Navigasi setelah splash + cek status login & verifikasi email
    Timer(const Duration(seconds: 3), _navigateBasedOnAuth);
  }

  void _navigateBasedOnAuth() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (user.emailVerified) {
        // Sudah login dan email terverifikasi
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Sudah login tapi email belum diverifikasi
        Navigator.pushReplacementNamed(context, '/login');
        // Atau arahkan ke halaman khusus verifikasi email
        // Navigator.pushReplacementNamed(context, '/verify-email');
      }
    } else {
      // Belum login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _logoAnimation,
                child: FadeTransition(
                  opacity: _logoAnimation,
                  child: Image.asset(
                    'assets/images/rambu_logo.png',
                    width: 150,
                    height: 150,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SlideTransition(
                position: _textSlideAnimation,
                child: FadeTransition(
                  opacity: _fadeText,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Rambu',
                          style: GoogleFonts.oswald(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: 'ID',
                          style: GoogleFonts.oswald(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
