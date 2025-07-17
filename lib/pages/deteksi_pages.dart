// Halaman Deteksi Rambu
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mjpeg_view/mjpeg_view.dart';
import 'package:rambu_idv2/utils/raspberry_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../screens/status_screen.dart';
import 'hasil_deteksi_pages.dart';
import 'pengaturan_page.dart';
import 'package:video_player/video_player.dart'; // untuk validasi durasi video
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';

WebSocketChannel? _channel;
StreamSubscription? _wsSubscription;
String? _detectedLabel;

class DeteksiRambuPage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final void Function(bool isDark) onToggleTheme;

  const DeteksiRambuPage({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
  });

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

  Uint8List? _decodedImageBytes;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn().then((_) {
      setState(() {
        _checkingLoginStatus = false;
      });
    });
    _loadSavedIP();
    _tryAutoConnectWifi();
  }

  Future<void> _tryAutoConnectWifi() async {
    final creds = await _getSavedWifiCredentials();
    final ssid = creds['ssid'];
    final password = creds['password'];

    if (ssid == null) return;

    final _ = await WiFiForIoTPlugin.isConnected();
    final currentSSID = await WiFiForIoTPlugin.getSSID();

    if (currentSSID == ssid) {
      debugPrint("Sudah tersambung ke $ssid");
      return;
    }

    debugPrint("Menyambung otomatis ke $ssid...");

    if (password == null) {
      await _connectToOpenNetwork(ssid);
    } else {
      await _connectToSelectedSSID(ssid, password);
    }
  }

  Future<void> _clearSavedWifi() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_ssid');
    await prefs.remove('saved_password');
    _showWifiInfo("Riwayat Wi-Fi telah dihapus.");
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<void> _sendUIDToServer(String ip) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken(); // 🔑 Ambil token Firebase
      final url = Uri.parse('http://$ip:8080/deteksi');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          debugPrint('✅ UID berhasil dikirim ke server');
        } else {
          debugPrint('❌ UID tidak diterima: ${body['detail']}');
        }
      } else {
        debugPrint('❌ Gagal mengirim UID: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error saat kirim UID: $e');
    }
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

  void _connectWebSocket(String ip) {
    final uri = Uri.parse('ws://$ip:8080/ws');

    _channel?.sink.close(); // Tutup channel sebelumnya kalau ada
    _channel = WebSocketChannel.connect(uri);

    _wsSubscription = _channel!.stream.listen(
      (data) {
        try {
          final parsed = jsonDecode(data);
          final base64Image = parsed['image'];
          final detections = parsed['detections'];

          if (detections != null && detections.isNotEmpty) {
            final label = detections.map((d) => d['label']).join(', ');
            final bytes = base64Decode(base64Image);
            setState(() {
              _detectedLabel = label;
              _decodedImageBytes = bytes;
            });
          }
        } catch (e) {
          debugPrint('Gagal decode WebSocket: $e');
        }
      },
      onError: (error) {
        debugPrint("WebSocket error: $error");
        setState(() {
          _detectedLabel = 'Koneksi WebSocket error';
        });
      },
      onDone: () {
        debugPrint("WebSocket connection closed");
      },
    );
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

    final testUrl = 'http://$ip:8080';

    setState(() {
      _status = 'Menguji koneksi...';
      _isChecking = true;
      _streamUrl = null;
    });

    try {
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _streamUrl = 'http://$ip:8080/video_feed';
          _status = 'Terhubung ke $testUrl';
        });
        _saveIP(ip);
        _connectWebSocket(ip); // 🔌 WebSocket aktif
        _sendUIDToServer(ip); // 🆕 Kirim UID setelah sukses koneksi
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
      _showUploadError("Ukuran file maksimal 5MB.");
      return;
    }

    // Cek ekstensi file
    final fileExtension = pickedFile.name.split('.').last.toLowerCase();
    if (fileExtension != 'jpg' &&
        fileExtension != 'jpeg' &&
        fileExtension != 'png') {
      _showUploadError("Hanya file PNG dan JPG yang diizinkan.");
      return;
    }

    // Cek dimensi gambar
    final image = await decodeImageFromList(file.readAsBytesSync());
    const maxWidth = 1920;
    const maxHeight = 1080;

    if (image.width > maxWidth || image.height > maxHeight) {
      _showUploadError("Resolusi maksimal adalah 1920x1080 piksel.");
      return;
    }

    // Jika semua validasi lolos, navigasi ke halaman hasil
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HasilDeteksiPage(imagePath: pickedFile.path),
      ),
    );
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (!mounted || pickedFile == null) return;

    final file = File(pickedFile.path);

    // Cek ekstensi file
    final fileExtension = pickedFile.name.split('.').last.toLowerCase();
    if (fileExtension != 'mp4') {
      _showUploadError("Hanya file MP4 yang diizinkan.");
      return;
    }

    // Cek durasi video
    final VideoPlayerController controller = VideoPlayerController.file(file);
    await controller.initialize();

    final duration = controller.value.duration.inSeconds;
    await controller.dispose();

    if (duration > 190) {
      _showUploadError("Durasi video maksimal adalah 190 detik.");
      return;
    }

    // Navigasi ke halaman hasil deteksi
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HasilDeteksiPage(
          videoPath: pickedFile.path,
          imagePath: '',
        ), // ⬅️ pastikan HasilDeteksiPage mendukung videoPath
      ),
    );
  }

  Future<void> _saveWifiCredentials(String ssid, String? password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_ssid', ssid);
    if (password != null) {
      await prefs.setString('saved_password', password);
    } else {
      await prefs.remove('saved_password');
    }
  }

  Future<Map<String, String?>> _getSavedWifiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final ssid = prefs.getString('saved_ssid');
    final password = prefs.getString('saved_password');
    return {'ssid': ssid, 'password': password};
  }

  Future<void> _connectToOpenNetwork(String ssid) async {
    try {
      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        security: NetworkSecurity.NONE,
        joinOnce: true,
        withInternet: false,
      );

      if (connected) {
        await _saveWifiCredentials(ssid, null); // Open = tidak ada password
        _goToConnectingScreen();
      } else {
        _showWifiInfo("Gagal menyambung ke $ssid (Open).");
      }
    } catch (e) {
      _showWifiInfo("Kesalahan: $e");
    }
  }

  Future<void> _handleConnectToRaspberry() async {
    final ip = _ipController.text.trim();

    setState(() {
      _status = "Menghubungkan...";
      _isChecking = true;
      _streamUrl = null;
    });

    await RaspberryConnector.connectToRaspberry(
      ip: ip,
      onStatus: (statusMsg) {
        setState(() {
          _status = statusMsg;
          if (statusMsg.contains("✅")) {
            _streamUrl = 'http://$ip:8080/video_feed';
          }
          _isChecking = false;
        });
      },
      onImageAndLabel: (imageBytes, label) {
        setState(() {
          _decodedImageBytes = imageBytes;
          _detectedLabel = label;
        });
      },
      onError: (errMsg) {
        _showSnackbarInfo(context, errMsg);
      },
    );
  }

  Future<void> _connectToSelectedSSID(String ssid, String password) async {
    try {
      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false,
      );

      if (connected) {
        await _saveWifiCredentials(ssid, password); // Simpan
        _goToConnectingScreen();
      } else {
        _showWifiInfo("Gagal menyambung ke $ssid.");
      }
    } catch (e) {
      _showWifiInfo("Terjadi kesalahan saat menyambung: $e");
    }
  }

  void _showPasswordDialog(String ssid) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Masukkan Password untuk '$ssid'"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Password Wi-Fi",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                _showWifiInfo("Password tidak boleh kosong.");
                return;
              }
              Navigator.pop(context);
              _connectToSelectedSSID(ssid, password);
            },
            child: const Text("Sambungkan"),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndConnectToWifi() async {
    await _requestLocationPermission();

    final wifiEnabled = await WiFiForIoTPlugin.isEnabled();
    if (!wifiEnabled) {
      await WiFiForIoTPlugin.setEnabled(true);
    }

    final List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
    if (networks.isEmpty) {
      _showWifiInfo("Tidak ada jaringan Wi-Fi ditemukan.");
      return;
    }

    // Filter SSID yang mengandung 'raspberry' atau semua jika mau general
    final filteredNetworks = networks
        .where((net) => net.ssid != null && net.ssid!.isNotEmpty)
        .toList();

    if (filteredNetworks.isEmpty) {
      _showWifiInfo("Tidak ada jaringan ditemukan.");
      return;
    }

    // Tampilkan SSID yang tersedia
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: filteredNetworks.length,
          itemBuilder: (context, index) {
            final ssid = filteredNetworks[index].ssid!;
            final isOpen = (filteredNetworks[index].capabilities ?? "")
                .toLowerCase()
                .contains("open");

            return ListTile(
              leading: Icon(isOpen ? Icons.wifi : Icons.lock),
              title: Text(ssid),
              subtitle: Text(isOpen ? "Jaringan Terbuka" : "WPA/WPA2"),
              onTap: () {
                Navigator.pop(context);
                if (isOpen) {
                  _connectToOpenNetwork(ssid);
                } else {
                  _showPasswordDialog(ssid);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _connectToHotspot() async {
    const ssid =
        "Pi-TRPL402"; // ganti dengan nama hotspot Raspberry-mu
    const password = "pbltrpl402m"; // ganti jika hotspot butuh password

    try {
      // Pastikan Wi-Fi aktif
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        await WiFiForIoTPlugin.setEnabled(true);
      }

      // Cek apakah sudah tersambung
      final connectedSSID = await WiFiForIoTPlugin.getSSID();
      if (connectedSSID == ssid) {
        _goToConnectingScreen();
        return;
      }

      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false,
      );

      if (connected) {
        _goToConnectingScreen();
      } else {
        _showWifiInfo("Gagal menyambung ke hotspot. Pastikan hotspot aktif.");
      }
    } catch (e) {
      _showWifiInfo("Terjadi kesalahan: $e");
    }
  }

  void _goToConnectingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StatusScreen(ip: '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_checkingLoginStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.providerData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Akses Ditolak"),
        ),
        body: const Center(
          child: Text("Akses ditolak. Silakan login terlebih dahulu."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deteksi Rambu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog(
                context,
                "Tentang Aplikasi",
                "Aplikasi ini digunakan untuk mendeteksi rambu lalu lintas melalui Raspberry Pi.",
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PengaturanPage()),
              );
            },
          ),
          Switch(
            value: widget.currentThemeMode == ThemeMode.dark,
            onChanged: widget.onToggleTheme,
            activeColor: Colors.amber,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Langkah 1: Koneksi IP Raspberry
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Langkah 1: Sambungkan IP Raspberry",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Masukkan IP Raspberry Pi',
                      hintText: 'Contoh: 192.168.1.10',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.device_hub),
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.wifi_tethering),
                    onPressed: _isChecking ? null : _handleConnectToRaspberry,
                    label: const Text('Cek Koneksi'),
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
                ],
              ),
            ),
          ),

          // Langkah 2: Live Stream
          AnimatedOpacity(
            opacity: _streamUrl != null ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 300),
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Langkah 2: Lihat Deteksi Langsung",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_streamUrl != null)
                      SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: MjpegView(
                          uri: _streamUrl!,
                          onError: (error, stack) {
                            debugPrint("Stream error: $error");
                            _showSnackbarInfo(
                              context,
                              "Gagal stream. Pastikan Raspberry Pi berjalan dan IP benar.",
                            );
                            setState(() {
                              _status =
                                  "Stream error. Coba cek koneksi atau restart Raspberry Pi. ($error)";
                            });
                          },
                        ),
                      ),
                    if (_detectedLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Deteksi: $_detectedLabel',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    if (_decodedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Image.memory(_decodedImageBytes!, height: 160),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Langkah 3: Upload File
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Langkah 3: Unggah File Manual",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImage,
                    label: const Text('Unggah Gambar'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.video_file),
                    onPressed: _pickVideo,
                    label: const Text('Unggah Video (MP4)'),
                  ),
                ],
              ),
            ),
          ),

          // Langkah 4: Hotspot/WiFi
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Opsional: Sambung ke Hotspot Raspberry",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.wifi),
                    onPressed: _connectToHotspot,
                    label: const Text("Sambung ke Hotspot Raspberry"),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.wifi_find),
                    onPressed: _scanAndConnectToWifi,
                    label: const Text("Pindai & Sambung ke Hotspot Raspberry"),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _clearSavedWifi,
                    icon: const Icon(Icons.wifi_off),
                    label: const Text("Lupakan Wi-Fi Tersimpan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadError(String message) {
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

  void _showWifiInfo(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Status Koneksi"),
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
    _wsSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

void _showInfoDialog(BuildContext context, String title, String message) {
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

void _showSnackbarInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red[400],
    ),
  );
}
