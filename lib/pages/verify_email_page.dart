import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:rambu_idv2/main.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with TickerProviderStateMixin, RouteAware {
  bool _canResend = false;
  bool _isChecking = false;
  Timer? _resendTimer;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Dipanggil ketika kembali ke halaman ini
    debugPrint("🔁 Kembali ke halaman verifikasi, kirim ulang jika perlu");
    _sendVerificationEmail(forceTimer: true);
  }

  static const int kResendDelay = 60;
  int _resendCountdown = kResendDelay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser == null) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _resendCountdown),
    );

    _progressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_progressController)
          ..addListener(() {
            setState(() {});
          });

    Future.delayed(const Duration(milliseconds: 100), () {
      _sendVerificationEmail(forceTimer: true);
    });
  }

  void _initializeTimerAndProgress() {
    _progressController.reset();
    _progressController.forward();

    _resendCountdown = 60;
    _canResend = false;

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendVerificationEmail({bool forceTimer = true}) async {
    final now = DateTime.now();

    if (_lastSentTime != null &&
        now.difference(_lastSentTime!) < _cooldownDuration) {
      debugPrint("⏱️ Email verifikasi masih dalam cooldown.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tunggu beberapa saat sebelum mengirim ulang email."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;

      // Tunggu jika user belum ready
      int retry = 0;
      while (user == null && retry < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        user = FirebaseAuth.instance.currentUser;
        retry++;
      }

      // TAMBAHKAN PENANGANAN JIKA USER NULL
      if (user == null) {
        debugPrint("❌ Gagal mendapatkan user. Kembali ke halaman login.");
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        _lastSentTime = now; // ✅ Simpan waktu kirim terakhir
        debugPrint("✅ Email verifikasi dikirim");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email verifikasi telah dikirim."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        debugPrint("⚠️ Email sudah diverifikasi.");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email kamu sudah diverifikasi."),
            backgroundColor: Colors.blue,
          ),
        );
      }

      /// 💡 PENTING: Jalankan timer dan progress bar **terlepas** dari status verifikasi
      if (forceTimer) {
        _initializeTimerAndProgress();
      }
    } catch (e) {
      debugPrint("❌ Gagal kirim email verifikasi: $e");

      if (forceTimer) {
        _initializeTimerAndProgress(); // 💡 Tetap jalankan timer walau gagal kirim
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Gagal mengirim email verifikasi: terlalu banyak permintaan verifikasi email dalam waktu singkat",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(seconds: 1)); // TAMBAH DELAY

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        _progressController.stop();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email belum diverifikasi."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error cek verifikasi: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal memeriksa status verifikasi."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.only(top: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        title: Column(
          children: [
            // Animasi ikon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: const Icon(
                Icons.logout_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Anda yakin ingin keluar?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Anda harus memverifikasi ulang saat ingin masuk.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.exit_to_app),
            label: const Text("Keluar"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _resendTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Verifikasi Email"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Gambar latar belakang
          Positioned.fill(
            child: Image.asset(
              'assets/images/verify-background.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: Colors.white.withValues(
                  alpha: 0.8,
                ), // untuk efek "overlay"
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_rounded,
                        size: 100,
                        color: Colors.orange[800],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Verifikasi Email Kamu",
                        style: GoogleFonts.oswald(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Kami telah mengirim link verifikasi ke email kamu.\nSilakan cek dan klik link tersebut.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 6,
                        color: Colors.orange,
                        backgroundColor: Colors.orange.shade100,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isChecking
                            ? null
                            : _checkVerificationStatus,
                        icon: const Icon(Icons.refresh),
                        label: _isChecking
                            ? Shimmer.fromColors(
                                baseColor: Colors.white54,
                                highlightColor: Colors.white,
                                child: const Text(
                                  "Memeriksa...",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const Text("Cek Status Verifikasi"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _canResend
                          ? TextButton(
                              onPressed: () =>
                                  _sendVerificationEmail(forceTimer: true),
                              child: const Text("Kirim Ulang Email Verifikasi"),
                            )
                          : Shimmer.fromColors(
                              baseColor: Colors.orange.shade200,
                              highlightColor: Colors.orange.shade100,
                              child: Text(
                                "Tunggu $_resendCountdown detik untuk kirim ulang.",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _logout,
                        child: const Text(
                          "Keluar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _lastSentTime;
final Duration _cooldownDuration = const Duration(seconds: 60);
