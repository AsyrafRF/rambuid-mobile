import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountStorage {
  static final _storage = FlutterSecureStorage();

  static Future<void> saveAccount({
    required String uid,
    required String email,
    required String password, // disarankan hanya jika aplikasi internal
  }) async {
    await _storage.write(
      key: uid,
      value: jsonEncode({"email": email, "password": password}),
    );
  }

  static Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final all = await _storage.readAll();
    return all.entries.map((e) {
      final data = jsonDecode(e.value);
      return {
        "uid": e.key,
        "email": data["email"],
        "password": data["password"],
      };
    }).toList();
  }

  static Future<void> deleteAccount(String uid) async {
    await _storage.delete(key: uid);
  }

  static Future<void> clearAllAccounts() async {
    await _storage.deleteAll();
  }
}
