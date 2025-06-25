// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';

import 'login_page.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String nickname = 'Loading...';
  List<String> riwayatRambu = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null || user!.isAnonymous || user!.email == null) {
      setState(() {
        nickname = 'Tamu';
        riwayatRambu = [];
      });
      return;
    }

    final docRef = firestore.collection('users').doc(user!.uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      final data = docSnap.data()!;
      setState(() {
        nickname = data['nickname'] ?? 'User';
        riwayatRambu = List<String>.from(data['riwayatRambu'] ?? []);
      });
    } else {
      await docRef.set({
        'nickname': user!.email!.split('@')[0],
        'riwayatRambu': [],
      });
      setState(() {
        nickname = user!.email!.split('@')[0];
        riwayatRambu = [];
      });
    }
  }

  Future<void> _editNickname() async {
    String newName = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ubah Nickname"),
        content: TextField(
          autofocus: true,
          onChanged: (value) => newName = value,
          decoration: const InputDecoration(
            hintText: "Masukkan nickname baru",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newName.trim().isNotEmpty) {
                await firestore.collection('users').doc(user!.uid).update({
                  'nickname': newName.trim(),
                });
                setState(() => nickname = newName.trim());
              }
              Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
    if (user?.isAnonymous == true || user?.email == null) return;
  }

  Future<void> _showLogoutConfirmationDialog() async {
    double scale = 0.7;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future.delayed(const Duration(milliseconds: 10), () {
              setState(() => scale = 1.0);
            });

            return Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: scale,
                curve: Curves.easeOutBack,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text("Anda yakin ingin keluar?"),
                  content: const Text(
                    "Anda harus login kembali saat ingin masuk.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection("active_user")
                              .doc(user.uid)
                              .set({"active": false}, SetOptions(merge: true));
                        }
                        await FirebaseAuth.instance.signOut();
                        Navigator.popUntil(context, (route) => route.isFirst);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Keluar"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // final emailDisplay = user?.email ?? 'Login sebagai tamu';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: Text(
          "Profil",
          style: GoogleFonts.oswald(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person, size: 48, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nickname,
                                style: GoogleFonts.oswald(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!(user?.isAnonymous == true ||
                                user?.email == null))
                              IconButton(
                                onPressed: _editNickname,
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: "Ubah nickname",
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'Login sebagai tamu',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            fontStyle: user?.isAnonymous == true
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Riwayat Rambu',
                style: GoogleFonts.oswald(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: riwayatRambu.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Lottie.asset(
                              'assets/animations/no_data.json',
                              width: 200,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user?.isAnonymous == true || user?.email == null
                                  ? "Login dengan email atau Google untuk melihat riwayat rambu."
                                  : "Belum ada riwayat.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.oswald(
                                fontSize: 15,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: riwayatRambu.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return Row(
                            children: [
                              const Icon(Icons.traffic, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  riwayatRambu[index],
                                  style: GoogleFonts.oswald(fontSize: 16),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _showLogoutConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'KELUAR',
                    style: GoogleFonts.oswald(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> updateUIDToFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final uid = user.uid;
  final email = user.email ?? "";

  await FirebaseFirestore.instance
      .collection("active_user")
      .doc(uid) // ✅ UID jadi ID dokumen
      .set({
        "uid": uid,
        "email": email,
        "lastLogin": FieldValue.serverTimestamp(),
        "active": true, // bisa digunakan untuk filter
      }, SetOptions(merge: true));
}
