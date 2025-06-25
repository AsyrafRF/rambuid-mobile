import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DetectionHistoryPage extends StatefulWidget {
  const DetectionHistoryPage({super.key});

  @override
  State<DetectionHistoryPage> createState() => _DetectionHistoryPageState();
}

class _DetectionHistoryPageState extends State<DetectionHistoryPage> {
  final bool _stretch = true;
  DateTime? _lastRefresh;

  bool _checkingLoginStatus = true;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn().then((_) {
      setState(() {
        _checkingLoginStatus = false;
      });
    });
  }

  Future<void> _checkIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;

    // Jika belum login sama sekali
    if (user == null) {
      _redirectToLogin();
      return;
    }

    // Ambil provider data
    final providers = user.providerData;

    // Jika kosong, berarti anonymous
    if (providers.isEmpty) {
      _redirectToLogin();
      return;
    }

    // Hanya izinkan provider Google dan Email/Password
    final allowedProviders = ['google.com', 'password'];

    // Cek apakah salah satu provider pengguna cocok dengan yang diizinkan
    final isAllowed = providers.any(
      (provider) => allowedProviders.contains(provider.providerId),
    );

    if (!isAllowed) {
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Akses Ditolak"),
          content: const Text(
            "Anda harus login menggunakan akun Google atau Email/Password untuk mengakses fitur ini.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                Navigator.of(
                  context,
                ).pushReplacementNamed('/login'); // Arahkan ke login
              },
              child: const Text("Login Sekarang"),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _refreshData() async {
    setState(() => _lastRefresh = DateTime.now());
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Disegarkan!')));
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      stretch: _stretch,
      onStretchTrigger: () async => await _refreshData(),
      stretchTriggerOffset: 300.0,
      expandedHeight: 180.0,
      centerTitle: true,
      pinned: false,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 12),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.traffic, color: Colors.orange, size: 20),
              const SizedBox(width: 6),
              Text(
                'Riwayat Rambu',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/logo.png', fit: BoxFit.cover),
            Container(), // Lapisan gelap untuk teks lebih jelas
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_circle,
                      size: 40,
                      color: Colors.orange,
                    ),
                  ),
                  if (_lastRefresh != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Terakhir disegarkan: ${_formatTime(_lastRefresh!)}',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionItem(DocumentSnapshot doc) {
    final String label = doc['label'] ?? '-';
    final String kategori = doc['kategori'] ?? '-';
    final dynamic timestampRaw = doc['timestamp'];
    DateTime dateTime;

    if (timestampRaw is Timestamp) {
      dateTime = timestampRaw.toDate();
    } else if (timestampRaw is String) {
      dateTime = DateTime.tryParse(timestampRaw) ?? DateTime.now();
    } else {
      dateTime = DateTime.now();
    }

    final String formattedTime = DateFormat.yMMMd().add_jm().format(dateTime);
    final int x1 = (doc['x1'] as num?)?.toInt() ?? 0;
    final int y1 = (doc['y1'] as num?)?.toInt() ?? 0;
    final int x2 = (doc['x2'] as num?)?.toInt() ?? 0;
    final int y2 = (doc['y2'] as num?)?.toInt() ?? 0;
    final String? base64Image = doc['image_base64'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Rambu: $label",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Kategori: $kategori",
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            Text(
              "Waktu: $formattedTime",
              style: GoogleFonts.roboto(fontSize: 16),
            ),
            Text(
              "Koordinat: ($x1, $y1) → ($x2, $y2)",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (base64Image != null && base64Image.isNotEmpty)
              Image.memory(
                base64Decode(base64Image),
                height: 200,
                fit: BoxFit.cover,
              )
            else
              const Text(
                'Gambar tidak tersedia',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamBuilder() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Pengguna tidak ditemukan.'),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('detections')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/gifs/no_data.gif', height: 200),
                  const SizedBox(height: 16),
                  const Text(
                    'Tidak ada data deteksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Data deteksi akan muncul di sini setelah tersedia.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == docs.length) {
              return const SizedBox(height: 80); // Spacer terakhir
            }
            return _buildDetectionItem(docs[index]);
          }, childCount: docs.length + 1),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLoginStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [_buildAppBar(), _buildStreamBuilder()],
        ),
      ),
    );
  }
}

// Future<void> updateUIDToFirestore() async {
//   String uid = FirebaseAuth.instance.currentUser!.uid;

//   await FirebaseFirestore.instance
//       .collection("active_user")
//       .doc("uid") // gunakan `uid` sebagai ID dokumen
//       .set({
//         "uid": uid,
//         "email": FirebaseAuth.instance.currentUser?.email ?? "",
//         "lastLogin": FieldValue.serverTimestamp(),
//         });
// }
