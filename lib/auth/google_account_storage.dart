import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GoogleAccountStorage {
  static final _storage = FlutterSecureStorage();

  static Future<void> saveGoogleAccount({
    required String uid,
    required String email,
    required String displayName,
    required String idToken,
    required String accessToken,
  }) async {
    final data = jsonEncode({
      "email": email,
      "displayName": displayName,
      "idToken": idToken,
      "accessToken": accessToken,
    });

    await _storage.write(key: uid, value: data);
  }

  static Future<List<Map<String, dynamic>>> getAllGoogleAccounts() async {
    final all = await _storage.readAll();
    return all.entries.map((e) {
      final decoded = jsonDecode(e.value);
      return {
        "uid": e.key,
        "email": decoded["email"],
        "displayName": decoded["displayName"],
        "idToken": decoded["idToken"],
        "accessToken": decoded["accessToken"],
      };
    }).toList();
  }

  static Future<void> deleteGoogleAccount(String uid) async {
    await _storage.delete(key: uid);
  }

  static Future<void> clearAllGoogleAccounts() async {
    await _storage.deleteAll();
  }
}
