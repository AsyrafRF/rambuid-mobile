// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../services/wifi_service.dart';

class WifiScanScreen extends StatefulWidget {
  const WifiScanScreen({super.key});

  @override
  _WifiScanScreenState createState() => _WifiScanScreenState();
}

class _WifiScanScreenState extends State<WifiScanScreen> {
  final wifiService = WifiService();
  List<String> ssids = [];
  String? selectedSSID;
  String password = '';
  bool connecting = false;
  String result = '';

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    try {
      ssids = await wifiService.scanWifi();
      setState(() {});
    } catch (e) {
      result = '❌ Gagal memuat jaringan WiFi';
      setState(() {});
    }
  }

  Future<void> _connect() async {
    if (selectedSSID == null || password.length < 8) {
      setState(() => result = '⚠ SSID atau password tidak valid');
      return;
    }

    setState(() {
      connecting = true;
      result = '';
    });

    final response = await wifiService.connect(selectedSSID!, password);
    if (response) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/status');
    } else {
      setState(() => result = '❌ Gagal koneksi. Hotspot diaktifkan ulang.');
      // Mungkin tambahkan countdown atau retry otomatis
    }

    final success = await wifiService.connect(selectedSSID!, password);

    if (success) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/status');
    } else {
      setState(() {
        result = '❌ Gagal koneksi. Hotspot akan tetap aktif.';
        connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text("🔍 Pilih Jaringan WiFi"),
              value: selectedSSID,
              items: ssids
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => selectedSSID = val),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: '🔑 Password'),
              onChanged: (val) => password = val,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: connecting ? null : _connect,
              child: Text(connecting ? 'Menghubungkan...' : '🔗 Hubungkan'),
            ),
            if (result.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(result, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
