// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/wifi_service.dart';
import '../utils/notification_helper.dart';

class ConnectingScreen extends StatefulWidget {
  @override
  _ConnectingScreenState createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  final wifiService = WifiService();
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  String message = 'Menghubungkan ke jaringan...';
  String connectionMessage = '';
  String? fallbackSSID;
  String? lastKnownIP;
  int countdown = 5;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      final result = await wifiService.checkStatusDetails();
      final currentIP = result['ip'];
      final connected = result['connected'] == true;
      final fallback = result['fallback'] == true;
      final ssid = result['ssid'] ?? 'RPi';

      if (connected) {
        // ✅ Cek jika IP berubah
        if (currentIP != null && currentIP != lastKnownIP) {
          lastKnownIP = currentIP;

          setState(() {
            connectionMessage = '✅ IP RPi berubah: $currentIP';
          });

          // Opsional: kirim notifikasi
          showIPChangeNotification(currentIP);
        }

        final ip = currentIP ?? 'Tidak diketahui';

        setState(() {
          connectionMessage = '✅ Tersambung ke internet.\nAlamat IP RPi: $ip';
        });

        _pollingTimer?.cancel();
        await Future.delayed(Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/status');
      } else if (fallback) {
        _pollingTimer?.cancel();

        if (!hasNotifiedFallback) {
          hasNotifiedFallback = true;
          showFallbackNotification(ssid);
        }

        setState(() {
          fallbackSSID = ssid;
          message =
              '❌ Gagal menghubungkan. Hotspot "$ssid" telah aktif kembali.\nSilakan sambung ulang.\nMengalihkan dalam $countdown detik...';
        });

        startCountdown();
      }
    });
  }

  void startCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (countdown == 0) {
        _countdownTimer?.cancel();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        setState(() => countdown--);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Menghubungkan...')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                connectionMessage.isNotEmpty ? connectionMessage : message,
                textAlign: TextAlign.center,
              ),
              if (message.contains('❌')) ...[
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    hasNotifiedFallback = false;
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  child: Text('Ulangi'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// Global flag untuk notifikasi fallback
bool hasNotifiedFallback = false;
