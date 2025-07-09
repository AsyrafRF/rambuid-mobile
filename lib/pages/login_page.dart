// ignore_for_file: library_private_types_in_public_api, unrelated_type_equality_checks

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/account_storage.dart';
import 'beranda_pages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  final _secureStorage = FlutterSecureStorage();

  Future<void> saveAccount(User user) async {
    await _secureStorage.write(
      key: user.uid,
      value: jsonEncode({
        "email": user.email,
        "uid": user.uid,
        // Jika ingin support login Google, simpan ID token (lihat catatan di bawah)
      }),
    );
  }

  Future<Map<String, dynamic>?> getSavedAccount(String uid) async {
    final json = await _secureStorage.read(key: uid);
    if (json != null) {
      return jsonDecode(json);
    }
    return null;
  }

  Future<List> getAllSavedAccounts() async {
    final all = await _secureStorage.readAll();
    return all.values.map((v) => jsonDecode(v)).toList();
  }

  Future<void> _login() async {
    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
      final remaining = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
      _showError(
        "Terlalu banyak percobaan gagal. Coba lagi dalam $remaining detik.",
      );
      return;
    }

    if (!await _checkInternetConnection()) {
      _showError("Tidak ada koneksi internet.");
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final isValidEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

    if (!isValidEmail) {
      _showError("Format email tidak valid.");
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      _showError("Email dan password tidak boleh kosong.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      await updateUIDToFirestore();

      if (user != null && user.emailVerified) {
        // Reset percobaan gagal
        _failedAttempts = 0;
        _lockoutEndTime = null;

        // ✅ Simpan akun login ke secure storage
        await AccountStorage.saveAccount(
          uid: user.uid,
          email: user.email!,
          password:
              password, // karena password = passwordController.text.trim()
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const BerandaPage(),
            settings: RouteSettings(
              arguments: {'successMessage': 'Login berhasil!'},
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/verify-email');
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          _failedAttempts++;
          if (_failedAttempts >= 3) {
            const int _ = 30;
            _showError(
              "Terlalu banyak percobaan gagal. Coba lagi dalam 30 detik.",
            );
          } else {
            _showError(
              "Email atau Password Salah. Percobaan ke $_failedAttempts dari 3.",
            );
          }
          break;
        default:
          _showError("Terjadi kesalahan: ${e.message}");
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!await _checkInternetConnection()) {
      _showError("Tidak ada koneksi internet.");
      return;
    }

    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showError("Masukkan email terlebih dahulu untuk reset password.");
      return;
    }

    final isValidEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    if (!isValidEmail) {
      _showError("Email tidak valid.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showDialog(
        "Berhasil",
        "Link reset password telah dikirim ke email kamu.",
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showError("Jika email terdaftar, link reset password telah dikirim.");
      } else if (e.code == 'invalid-email') {
        _showError("Format email tidak valid.");
      } else {
        _showError("Gagal mengirim reset password: ${e.message}");
      }
    } catch (_) {
      _showError("Gagal mengirim reset password. Pastikan email valid.");
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!await _checkInternetConnection()) {
      _showError("Tidak ada koneksi internet.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Inisialisasi GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Tampilkan popup akun Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User membatalkan login
        setState(() => _isLoading = false);
        return;
      }

      // Ambil token autentikasi
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Konversi ke credential Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Login ke Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // Simpan UID ke Firestore (opsional, sudah ada di kode kamu)
      await updateUIDToFirestore();

      if (userCredential.user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const BerandaPage(),
            settings: const RouteSettings(
              arguments: {'successMessage': 'Login berhasil!'},
            ),
          ),
        );
      }
    } catch (e) {
      _showError("Gagal login dengan Google: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginAsGuest() async {
    if (!await _checkInternetConnection()) {
      _showError("Tidak ada koneksi internet.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();

      if (userCredential.user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const BerandaPage(),
            settings: RouteSettings(
              arguments: {'successMessage': 'Login sebagai tamu berhasil!'},
            ),
          ),
        );
      } else {
        // Jika userCredential null, fallback ke guest lokal
        _fallbackGuestLogin();
      }
    } catch (e) {
      // Gagal sign in anonymous → fallback ke guest lokal
      _fallbackGuestLogin();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _fallbackGuestLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BerandaPage(),
        settings: RouteSettings(
          arguments: {
            'successMessage': 'Login tamu tanpa autentikasi Firebase!',
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Login Gagal"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: SafeArea(
        child: Stack(
          children: [
            // Konten utama
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Image.asset('assets/images/rambu_logo.png', width: 100),
                      const SizedBox(height: 16),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Rambu',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: 'ID',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Silahkan masuk',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: const Text(
                            "Lupa password?",
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text("atau"),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithGoogle,
                        icon: Image.asset('assets/icons/google.png', width: 24),
                        label: const Text("Masuk dengan Google"),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: const BorderSide(color: Colors.orange),
                          foregroundColor: Colors.orange,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginAsGuest,
                        icon: const Icon(Icons.person_outline),
                        label: const Text("Masuk sebagai Tamu"),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: const BorderSide(color: Colors.grey),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Belum punya akun?'),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              '/register',
                            ),
                            child: const Text(
                              'Daftar disini!',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ Overlay loading
            if (_isLoading)
              Container(
                color: Colors.black.withAlpha(127), // 127 ≈ 0.5 opacity
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> updateUIDToFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final uid = user.uid;
  final email = user.email ?? "";

  await FirebaseFirestore.instance.collection("active_user").doc(uid).set({
    "uid": uid,
    "email": email,
    "lastLogin": FieldValue.serverTimestamp(),
    "active": true,
  }, SetOptions(merge: true));
}

final _secureStorage = FlutterSecureStorage();

Future<void> saveAccount(User user) async {
  await _secureStorage.write(
    key: user.uid,
    value: jsonEncode({"email": user.email, "uid": user.uid}),
  );
}

Future<Map<String, dynamic>?> getSavedAccount(String uid) async {
  final json = await _secureStorage.read(key: uid);
  if (json != null) {
    return jsonDecode(json);
  }
  return null;
}

Future<List> getAllSavedAccounts() async {
  final all = await _secureStorage.readAll();
  return all.values.map((v) => jsonDecode(v)).toList();
}
