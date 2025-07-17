import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnImageAndLabel = void Function(Uint8List imageBytes, String label);
typedef OnConnectionStatus = void Function(String status);
typedef OnWebSocketError = void Function(String message);

class RaspberryConnector {
  static const _ipPrefKey = 'raspberry_ip';

  static Future<bool> isValidIP(String ip) async {
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|1\d{2}|[1-9]?\d)\.){3}'
      r'(25[0-5]|2[0-4][0-9]|1\d{2}|[1-9]?\d)$',
    );
    return ipRegex.hasMatch(ip);
  }

  static Future<void> connectToRaspberry({
    required String ip,
    required OnConnectionStatus onStatus,
    required OnImageAndLabel onImageAndLabel,
    required OnWebSocketError onError,
  }) async {
    if (!await isValidIP(ip)) {
      onStatus("IP tidak valid. Format: 192.168.x.x");
      return;
    }

    final testUrl = 'http://$ip:8080';

    onStatus("Menguji koneksi ke $testUrl...");

    try {
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        onStatus("Gagal terhubung (kode ${response.statusCode})");
        return;
      }

      // Kirim UID/token ke port 8080
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onStatus("Pengguna tidak ditemukan.");
        return;
      }

      final idToken = await user.getIdToken();

      final tokenResponse = await http.post(
        Uri.parse("http://$ip:8080/deteksi"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_token": idToken}),
      );

      if (tokenResponse.statusCode == 200) {
        final result = jsonDecode(tokenResponse.body);
        if (result['status'] == 'success') {
          onStatus("✅ Terhubung & Token berhasil dikirim");
        } else {
          onStatus("⚠️ Gagal verifikasi token: ${result['detail']}");
        }
      } else {
        onStatus("❌ Token gagal dikirim ke Raspberry");
      }

      // Simpan IP ke shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ipPrefKey, ip);

      // WebSocket untuk video
      final wsUrl = Uri.parse('ws://$ip:8080/ws');
      final channel = WebSocketChannel.connect(wsUrl);

      channel.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data);
            final base64Image = parsed['image'];
            final detections = parsed['detections'];

            if (detections != null && detections.isNotEmpty) {
              final label = detections.map((d) => d['label']).join(', ');
              final imageBytes = base64Decode(base64Image);
              onImageAndLabel(imageBytes, label);
            }
          } catch (e) {
            onError("Gagal parsing WebSocket: $e");
          }
        },
        onError: (e) => onError("WebSocket error: $e"),
        onDone: () => onStatus("🔌 Koneksi WebSocket ditutup."),
      );
    } on TimeoutException {
      onStatus("⏱️ Timeout: Periksa koneksi jaringan.");
    } on SocketException {
      onStatus("📡 Tidak dapat menghubungi perangkat.");
    } catch (e) {
      onStatus("❌ Gagal koneksi: $e");
    }
  }
}
