import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'beranda_pages.dart';

class SwitchAccountPage extends StatefulWidget {
  const SwitchAccountPage({super.key});

  @override
  State<SwitchAccountPage> createState() => _SwitchAccountPageState();
}

class _SwitchAccountPageState extends State<SwitchAccountPage> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final all = await _storage.readAll();
    final accounts = all.entries.map((entry) {
      final data = jsonDecode(entry.value);
      return {
        'uid': entry.key,
        'email': data['email'],
        'password': data['password'],
        'idToken': data['idToken'],
        'accessToken': data['accessToken'],
        'customToken': data['customToken'],
      };
    }).toList();

    setState(() => savedAccounts = accounts);
  }

  Future<void> _loginAccount(Map<String, dynamic> account) async {
    try {
      if (account['idToken'] != null && account['accessToken'] != null) {
        // Google login
        final credential = GoogleAuthProvider.credential(
          idToken: account['idToken'],
          accessToken: account['accessToken'],
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      } else if (account['customToken'] != null) {
        await FirebaseAuth.instance.signInWithCustomToken(
          account['customToken'],
        );
      } else if (account['email'] != null && account['password'] != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: account['email'],
          password: account['password'],
        );
      } else {
        throw Exception("Tipe akun tidak dikenali.");
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BerandaPage(
            currentThemeMode: ThemeMode.light,
            onToggleTheme: (bool isDark) {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal login ulang: $e")));
    }
  }

  Future<void> _hapusAkun(String uid) async {
    await _storage.delete(key: uid);
    await _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ganti Akun")),
      body: savedAccounts.isEmpty
          ? const Center(child: Text("Tidak ada akun tersimpan."))
          : ListView.builder(
              itemCount: savedAccounts.length,
              itemBuilder: (context, index) {
                final acc = savedAccounts[index];
                return ListTile(
                  leading: const Icon(
                    Icons.account_circle,
                    color: Colors.orange,
                  ),
                  title: Text(acc['email'] ?? 'Tanpa Email'),
                  subtitle: acc['idToken'] != null
                      ? const Text("Google Account")
                      : acc['customToken'] != null
                      ? const Text("Custom Token")
                      : const Text("Email & Password"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _hapusAkun(acc['uid']),
                  ),
                  onTap: () => _loginAccount(acc),
                );
              },
            ),
    );
  }
}
