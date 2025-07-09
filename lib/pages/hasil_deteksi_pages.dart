import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HasilDeteksiPage extends StatefulWidget {
  final String imagePath;
  final String? videoPath;

  const HasilDeteksiPage({super.key, required this.imagePath, this.videoPath});

  @override
  State<HasilDeteksiPage> createState() => _HasilDeteksiPageState();
}

class _HasilDeteksiPageState extends State<HasilDeteksiPage> {
  String hasilDeteksi = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndDetect();
  }

  Future<void> _loadAndDetect() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('raspberry_ip');

    if (ip == null || ip.isEmpty) {
      setState(() {
        hasilDeteksi = 'IP Raspberry Pi belum disetel.';
        isLoading = false;
      });
      return;
    }

    final uri = Uri.parse('http://$ip:5000/deteksi');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath('image', widget.imagePath),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        setState(() {
          hasilDeteksi = data['label'] ?? 'Tidak dikenali';
          isLoading = false;
        });
      } else {
        setState(() {
          hasilDeteksi =
              'Gagal mendeteksi gambar (kode: ${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasilDeteksi = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Deteksi Rambu')),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.file(File(widget.imagePath)),
                  const SizedBox(height: 20),
                  Text(
                    'Hasil Deteksi: $hasilDeteksi',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
