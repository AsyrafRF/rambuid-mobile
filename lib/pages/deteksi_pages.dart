// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mjpeg_view/mjpeg_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hasil_deteksi_pages.dart';
import 'pengaturan_page.dart';

class DeteksiRambuPage extends StatefulWidget {
  const DeteksiRambuPage({super.key});

  @override
  State<DeteksiRambuPage> createState() => _DeteksiRambuPageState();
}

class _DeteksiRambuPageState extends State<DeteksiRambuPage> {
  final TextEditingController _ipController = TextEditingController();
  String? _streamUrl;
  String _status = 'Belum terhubung';
  bool _isChecking = false;

  static const String ipPrefKey = 'raspberry_ip';

  bool _checkingLoginStatus = true;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn().then((_) {
      setState(() {
        _checkingLoginStatus = false;
      });
    });
    _loadSavedIP();
  }

  Future<void> _checkIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;

    // Jika belum login sama sekali
    if (user == null) {
      _redirectToLogin();
      return;
    }

    // Ambil provider data
    final providers = user.providerData;

    // Jika kosong, berarti anonymous
    if (providers.isEmpty) {
      _redirectToLogin();
      return;
    }

    // Hanya izinkan provider Google dan Email/Password
    final allowedProviders = ['google.com', 'password'];

    // Cek apakah salah satu provider pengguna cocok dengan yang diizinkan
    final isAllowed = providers.any(
      (provider) => allowedProviders.contains(provider.providerId),
    );

    if (!isAllowed) {
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Akses Ditolak"),
          content: const Text(
            "Anda harus login menggunakan akun Google atau Email/Password untuk mengakses fitur ini.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                Navigator.of(
                  context,
                ).pushReplacementNamed('/login'); // Arahkan ke login
              },
              child: const Text("Login Sekarang"),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadSavedIP() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIP = prefs.getString(ipPrefKey);
    if (savedIP != null) {
      _ipController.text = savedIP;
      _checkConnection(savedIP);
    }
  }

  Future<void> _saveIP(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ipPrefKey, ip);
  }

  bool _isValidIP(String ip) {
    // Regex IP v4 yang valid
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|1\d{2}|[1-9]?\d)\.){3}'
      r'(25[0-5]|2[0-4][0-9]|1\d{2}|[1-9]?\d)$',
    );

    if (!ipRegex.hasMatch(ip)) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final numPart = int.tryParse(part);
      if (numPart == null || numPart < 0 || numPart > 255) {
        return false;
      }
    }

    // ✅ Tambahkan return true
    return true;
  }

  Future<void> _checkConnection([String? manualIP]) async {
    final ip = manualIP ?? _ipController.text.trim();
    if (ip.isEmpty) return;

    if (!_isValidIP(ip)) {
      setState(() {
        _status = 'IP tidak valid. Gunakan format: 192.168.x.x';
      });
      return;
    }

    final testUrl = 'http://$ip:8081';

    setState(() {
      _status = 'Menguji koneksi...';
      _isChecking = true;
      _streamUrl = null;
    });

    try {
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() {
          _streamUrl = testUrl;
          _status = 'Terhubung ke $testUrl';
        });
        _saveIP(ip);
      } else {
        setState(() {
          _status = 'Gagal terhubung: kode ${response.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        _status = 'Timeout: Periksa koneksi jaringan.';
      });
    } on SocketException {
      setState(() {
        _status = 'Tidak dapat menghubungi perangkat.';
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal: ${e.runtimeType}';
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (!mounted || pickedFile == null) return;

    final file = File(pickedFile.path);

    // Cek ukuran file (maksimal 5 MB)
    final fileSize = await file.length(); // dalam byte
    const maxSizeInBytes = 5 * 1024 * 1024; // 5 MB
    if (fileSize > maxSizeInBytes) {
      _showError("Ukuran file maksimal 5MB.");
      return;
    }

    // Cek ekstensi file
    final fileExtension = pickedFile.name.split('.').last.toLowerCase();
    if (fileExtension != 'jpg' &&
        fileExtension != 'jpeg' &&
        fileExtension != 'png') {
      _showError("Hanya file PNG dan JPG yang diizinkan.");
      return;
    }

    // Cek dimensi gambar
    final image = await decodeImageFromList(file.readAsBytesSync());
    const maxWidth = 1920;
    const maxHeight = 1080;

    if (image.width > maxWidth || image.height > maxHeight) {
      _showError("Resolusi maksimal adalah 1920x1080 piksel.");
      return;
    }

    // Jika semua validasi lolos, navigasi ke halaman hasil
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HasilDeteksiPage(imagePath: pickedFile.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLoginStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.providerData.isEmpty) {
      // Pengguna tidak valid atau anonymous
      return const Scaffold(
        body: Center(
          child: Text("Akses ditolak. Silakan login terlebih dahulu."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deteksi Rambu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PengaturanPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Masukkan IP Raspberry Pi',
                hintText: 'Contoh: 192.168.1.10',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: (text) {
                setState(() {
                  _status = 'Belum terhubung';
                  _streamUrl = null;
                });
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isChecking ? null : _checkConnection,
              child: const Text('Cek Koneksi'),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(
                color: _status.startsWith('Terhubung')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            if (_streamUrl != null)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: MjpegView(
                  uri: _streamUrl!,
                  onError: (error, stack) =>
                      const Text('Gagal menampilkan stream'),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              "Deteksi melalui Gambar:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Unggah Gambar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unggah Gagal"),
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
}
