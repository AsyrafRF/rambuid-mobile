// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wifi_service.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key, required String ip});

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final wifiService = WifiService();
  String statusMessage = 'Mengecek koneksi...';
  String? ssid;
  String? lastKnownIP;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _loadLastKnownIP();
  }

  Future<void> _loadLastKnownIP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastKnownIP = prefs.getString('last_ip');
    });
  }

  Future<void> _checkConnection() async {
    final ok = await wifiService.checkStatus();
    final current = await wifiService.currentSSID();
    setState(() {
      connected = ok;
      ssid = current;
      statusMessage = ok
          ? '✅ Terhubung ke internet via "$ssid"'
          : '❌ Tidak terhubung ke internet';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Status Koneksi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected ? Icons.wifi : Icons.wifi_off,
                size: 80,
                color: connected ? Colors.green : Colors.red,
              ),
              SizedBox(height: 20),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
