import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '../services/account_service.dart';
import 'login_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'switch_account_page.dart';

Uint8List decodeIkon(String? base64) {
  try {
    return base64 != null ? base64Decode(base64) : Uint8List(0);
  } catch (_) {
    return Uint8List(0);
  }
}

class RingkasanRambu {
  final String label;
  final String waktu;
  final Uint8List ikon;
  RingkasanRambu({
    required this.label,
    required this.waktu,
    required this.ikon,
  });
}

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});
  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String nickname = 'Loading...';
  List<Map<String, dynamic>> riwayatRambu = [];
  List<RingkasanRambu> riwayatTerbaru = [];
  @override
  void initState() {
    super.initState();
    _loadUserDataAndRiwayat();
  }

  final _secureStorage = FlutterSecureStorage();

  Future<void> saveAccount(User user) async {
    await _secureStorage.write(
      key: user.uid,
      value: jsonEncode({
        "email": user.email,
        "uid": user.uid,
        // Jika ingin support login Google, simpan ID token (lihat catatan di bawah)
      }),
    );
  }

  Future<Map<String, dynamic>?> getSavedAccount(String uid) async {
    final json = await _secureStorage.read(key: uid);
    if (json != null) {
      return jsonDecode(json);
    }
    return null;
  }

  Future<List> getAllSavedAccounts() async {
    final all = await _secureStorage.readAll();
    return all.values.map((v) => jsonDecode(v)).toList();
  }

  Future<void> _loadUserDataAndRiwayat() async {
    if (user == null || user!.isAnonymous || user!.email == null) {
      setState(() {
        nickname = 'Tamu';
        riwayatTerbaru = [];
      });
      return;
    }
    final docRef = firestore.collection('users').doc(user!.uid);
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      final data = docSnap.data()!;
      nickname = data['nickname'] ?? user!.email!.split('@')[0];
    } else {
      await docRef.set({'nickname': user!.email!.split('@')[0]});
      nickname = user!.email!.split('@')[0];
    }
    // Ambil semua ikon master_rambu dulu
    final masterSnapshot = await firestore.collection('master_rambu').get();
    String normalisasiLabel(String label) {
      return label
          .toLowerCase()
          .replaceAll('-', ' ')
          .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
          .trim();
    }

    final ikonMap = {
      for (var doc in masterSnapshot.docs)
        normalisasiLabel(doc['nama'] as String): decodeIkon(doc['ikon_base64']),
    };
    // Ambil 5 riwayat deteksi terbaru
    final detections = await firestore
        .collection('users')
        .doc(user!.uid)
        .collection('detections')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();
    List<RingkasanRambu> hasil = detections.docs.map((doc) {
      final label = doc['label'] ?? 'Tidak dikenal';
      DateTime? waktuDeteksi;
      final rawTimestamp = doc['timestamp'];
      if (rawTimestamp is Timestamp) {
        waktuDeteksi = rawTimestamp.toDate();
      } else if (rawTimestamp is String) {
        try {
          waktuDeteksi = DateTime.parse(rawTimestamp);
        } catch (_) {
          waktuDeteksi = null;
        }
      }
      final lokalWaktu = waktuDeteksi?.toLocal();
      final waktu = lokalWaktu != null
          ? "${lokalWaktu.hour.toString().padLeft(2, '0')}:${lokalWaktu.minute.toString().padLeft(2, '0')}"
          : '-';
      final ikon = ikonMap[normalisasiLabel(label)] ?? Uint8List(0);
      return RingkasanRambu(label: label, waktu: waktu, ikon: ikon);
    }).toList();

    if (mounted) {
      setState(() {
        riwayatTerbaru = hasil;
      });
    }
  }

  void showToast(String message, {Color backgroundColor = Colors.black}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<void> _editNickname() async {
    String newName = '';
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                if (!mounted) return;
                setState(() => nickname = newName.trim());
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<bool> showConfirmationDialog(BuildContext context) async {
    String input = '';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Hapus Akun"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Akun akan dihapus secara permanen beserta seluruh data deteksi Anda.",
                ),
                const SizedBox(height: 12),
                const Text(
                  "Ketik KONFIRMASI (huruf kapital) untuk melanjutkan:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) => input = value.trim(),
                  decoration: const InputDecoration(
                    hintText: "KONFIRMASI",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (input == "KONFIRMASI") {
                    Navigator.pop(ctx, true);
                  } else {
                    showToast(
                      "Silakan ketik KONFIRMASI dengan huruf kapital",
                      backgroundColor: Colors.orange,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Hapus"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showLogoutConfirmationDialog() async {
    double scale = 0.7;
    await showDialog(
      context: context,
      builder: (dialogContext) {
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
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("Batal"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (user != null) {
                          await firestore
                              .collection("active_user")
                              .doc(user!.uid)
                              .set({"active": false}, SetOptions(merge: true));
                        }
                        await FirebaseAuth.instance.signOut();
                        // Gunakan navigatorContext yang terikat dengan dialog
                        if (!mounted) return;
                        // Setelah keluar dari dialog, navigasi ke halaman login
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.pop(dialogContext);
                          }
                          Navigator.of(dialogContext).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        });
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

  void _showAppInfoDialog() {
    showAboutDialog(
      context: context,
      applicationName: "RambuID",
      applicationVersion: "v1.2.0+4",
      applicationIcon: Image.asset(
        "assets/icons/app_icon.png",
        width: 48,
        height: 48,
      ),
      children: [
        const SizedBox(height: 8),
        const Text(
          "Aplikasi deteksi rambu lalu lintas berbasis AI.\nDikembangkan oleh Tim PBL-TRPL402 Polibatam.",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
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
                "Riwayat Rambu",
                style: GoogleFonts.oswald(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (riwayatTerbaru.isEmpty)
                Center(
                  child: Column(
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
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: riwayatTerbaru.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rambu = riwayatTerbaru[index];
                    return Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.grey.shade300,
                          ),
                          child: rambu.ikon.isNotEmpty
                              ? Image.memory(rambu.ikon, fit: BoxFit.contain)
                              : const Icon(Icons.traffic, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 40,
                            ), // Misalnya 40 px minimum
                            child: Text(
                              rambu.label,
                              style: GoogleFonts.oswald(
                                fontSize: 16,
                                height: 1.2,
                              ),
                              softWrap: true,
                            ),
                          ),
                        ),
                        Text(
                          rambu.waktu,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    );
                  },
                ),
              SizedBox(height: 16),
              Divider(color: Colors.grey, thickness: 1),
              SizedBox(height: 16),

              // 🔽 Tambahkan bagian ini di atas tombol Keluar
              ListTile(
                leading: const Icon(Icons.switch_account, color: Colors.orange),
                title: const Text("Ganti Akun"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SwitchAccountPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Hapus Akun"),
                onTap: () async {
                  final service = AccountService();
                  final confirmed = await showConfirmationDialog(context);
                  if (confirmed) {
                    if (!context.mounted) return;
                    await service.deleteAccountWithPagination(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                title: const Text("Info Aplikasi"),
                onTap: _showAppInfoDialog,
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
                    "KELUAR",
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
