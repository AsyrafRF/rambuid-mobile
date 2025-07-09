import 'dart:convert';
import 'package:http/http.dart' as http;

class WifiService {
  static const String baseUrl = 'http://192.168.4.1'; // Ganti jika Pi terhubung ke router

  Future<List<String>> scanWifi() async {
    final response = await http.get(Uri.parse('$baseUrl/wifi/scan'));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body)['networks'];
      return List<String>.from(jsonList);
    } else {
      throw Exception('Gagal scan WiFi');
    }
  }

  Future<bool> connect(String ssid, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/wifi/connect'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ssid': ssid, 'password': password}),
    );
    return response.statusCode == 200;
  }

  Future<bool> checkStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/wifi/status'));
    if (response.statusCode == 200) {
      return json.decode(response.body)['connected'] == true;
    } else {
      return false;
    }
  }

  Future<Map<String, dynamic>> checkStatusDetails() async {
    final response = await http.get(Uri.parse('$baseUrl/wifi/status'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {'connected': false, 'fallback': false};
    }
  }

  Future<String?> currentSSID() async {
    final response = await http.get(Uri.parse('$baseUrl/wifi/info'));
    if (response.statusCode == 200) {
      return json.decode(response.body)['ssid'];
    }
    return null;
  }
}
