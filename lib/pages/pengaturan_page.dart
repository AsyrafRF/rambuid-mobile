// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  static const String ipPrefKey = 'raspberry_ip';
  String? savedIP;
  final TextEditingController _newIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedIP();
  }

  Future<void> _loadSavedIP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedIP = prefs.getString(ipPrefKey);
    });
  }

  bool _isValidIP(String ip) {
    final ipRegex = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');

    if (!ipRegex.hasMatch(ip)) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final numPart = int.tryParse(part);
      if (numPart == null || numPart < 0 || numPart > 255) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveNewIP() async {
    final newIP = _newIpController.text.trim();

    if (!_isValidIP(newIP)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Format IP tidak valid. Contoh: 192.168.0.10"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ipPrefKey, newIP);
    setState(() {
      savedIP = newIP;
      _newIpController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("IP berhasil disimpan"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _clearIP() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ipPrefKey);
    setState(() {
      savedIP = null;
      _newIpController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("IP berhasil dihapus")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "IP Raspberry Pi Tersimpan:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(savedIP ?? "Belum ada IP disimpan"),
            const SizedBox(height: 16),
            if (savedIP != null)
              ElevatedButton.icon(
                onPressed: _clearIP,
                icon: const Icon(Icons.delete),
                label: const Text("Hapus IP"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            const Divider(height: 32),
            const Text(
              "Ganti / Tambah IP:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newIpController,
              decoration: const InputDecoration(
                labelText: 'IP baru (misalnya: 192.168.0.12)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _saveNewIP,
              icon: const Icon(Icons.save),
              label: const Text("Simpan IP Baru"),
            ),
          ],
        ),
      ),
    );
  }
}
