// ignore_for_file: library_private_types_in_public_api

import 'dart:math';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rambu_idv2/pages/riwayat_deteksi_pages.dart';
import 'daftar_rambu_pages.dart';
import 'deteksi_pages.dart';
import 'profil_page.dart';

class BerandaPage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final void Function(bool isDark) onToggleTheme;

  const BerandaPage({
    super.key,
    required this.currentThemeMode,
    required this.onToggleTheme,
  });

  @override
  _BerandaPageState createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  int _currentIndex = 0;
  bool _isSnackbarShown = false; // Mencegah snackbar muncul berulang

  void _navigateWithTheme(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      _navigateWithTheme(
        DeteksiRambuPage(
          currentThemeMode: widget.currentThemeMode,
          onToggleTheme: widget.onToggleTheme,
        ),
      );
    } else if (index == 2) {
      _navigateWithTheme(const RambuListPage());
    } else if (index == 3) {
      _navigateWithTheme(const DetectionHistoryPage());
    } else if (index == 4) {
      _navigateWithTheme(const ProfilPage());
    }
  }

  Future<Map<String, dynamic>?> _getLastDetection() async {
    final user = FirebaseAuth.instance.currentUser;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('detections')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  Map<String, dynamic>? _lastDetection;

  void _loadLastDetection() async {
    final data = await _getLastDetection();
    setState(() {
      _lastDetection = data;
    });
  }

  Future<List<FlSpot>> getChartData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('detections')
        .get();

    // Inisialisasi list jumlah per hari (Senin = 0, Minggu = 6)
    final counts = List<int>.filled(7, 0);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      DateTime date;

      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.tryParse(timestamp) ?? DateTime.now();
      } else {
        continue;
      }

      final weekday = date.weekday % 7; // Sen = 1 → 1%7=1, Min = 7 → 0
      counts[weekday] += 1;
    }

    return List.generate(
      7,
      (index) => FlSpot(index.toDouble(), counts[index].toDouble()),
    );
  }

  Future<void> _loadSavedIP() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIP = prefs.getString('raspberry_ip');

    if (savedIP != null) {
      setState(() {
        _raspberryIP = savedIP;
      });
      _loadRaspberryStatus(); // setelah IP dapat, cek status
    }
  }

  Future<bool> _checkRaspberryPiStatus(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/healthz'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'ok';
      }
    } catch (e) {
      debugPrint('Gagal mengecek status Raspberry Pi: $e');
    }
    return false;
  }

  String? _raspberryIP;

  bool _isPiOnline = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIP();
    _loadLastDetection();
  }

  void _loadRaspberryStatus() async {
    if (_raspberryIP == null) return;
    final status = await _checkRaspberryPiStatus(_raspberryIP!);
    setState(() {
      _isPiOnline = status;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ambil argumen dari Navigator dan tampilkan snackbar jika ada pesan sukses
    final args = ModalRoute.of(context)?.settings.arguments;
    if (!_isSnackbarShown && args is Map && args['successMessage'] != null) {
      _isSnackbarShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(args['successMessage']),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = widget.currentThemeMode;
    final toggleTheme = widget.onToggleTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoWithButton(),

              const SizedBox(height: 32),

              // 📦 Menu Atas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMainMenu(
                    icon: 'assets/icons/ikon_daftar_rambu.png',
                    label: 'Daftar Rambu',
                    color: const Color(0xFFFFF3DD),
                    onTap: () {
                      _navigateWithTheme(const RambuListPage());
                    },
                  ),
                  _buildMainMenu(
                    icon: 'assets/icons/ikon_riwayat_rambu.png',
                    label: 'Riwayat Rambu',
                    color: const Color(0xFFFFF3DD),
                    onTap: () {
                      _navigateWithTheme(const DetectionHistoryPage());
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 🧭 Filter Kategori
              Center(
                child: Text(
                  "Kategori Rambu",
                  style: GoogleFonts.oswald(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                physics:
                    const NeverScrollableScrollPhysics(), // Biar tidak scroll sendiri
                shrinkWrap: true, // Biar tinggi otomatis sesuai isi
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio:
                    1.8, // Sesuaikan dengan rasio lebar/tinggi tombol
                children: [
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_peringatan.png',
                    'Rambu Peringatan',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RambuListPage(
                            initialFilterJenis: 'Peringatan',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_larangan.png',
                    'Rambu Larangan',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RambuListPage(
                            initialFilterJenis: 'Larangan',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_petunjuk.png',
                    'Rambu Petunjuk',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RambuListPage(
                            initialFilterJenis: 'Petunjuk',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_informasi.png',
                    'Rambu Informasi',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RambuListPage(
                            initialFilterJenis: 'Informasi',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ✅ Status Raspberry dan User
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildPiStatus(), _buildUserStatus()],
              ),

              const SizedBox(height: 24),

              // 🕵️ Terakhir Terdeteksi
              if (_lastDetection != null) ...[
                Text(
                  "Deteksi Terakhir",
                  style: GoogleFonts.oswald(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLastDetectionCard(),
                const SizedBox(height: 24),
              ],

              // 📈 Grafik Deteksi
              Text(
                "Grafik Deteksi",
                style: GoogleFonts.oswald(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetectionChart(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🌞'),
                  Switch(
                    value: themeMode == ThemeMode.dark,
                    onChanged: toggleTheme,
                    activeColor: Colors.amber,
                  ),
                  const Text('🌙'),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.raspberryPi),
              label: 'Deteksi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: 'Daftar Rambu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _buildPiStatus() {
    return Row(
      children: [
        Icon(
          Icons.circle,
          color: _isPiOnline ? Colors.green : Colors.red,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(
          _isPiOnline ? 'Raspberry Pi Online' : 'Raspberry Pi Offline',
          style: GoogleFonts.oswald(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildLogoWithButton() {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/rambu_logo.png', width: 130),
                const SizedBox(width: 1),
                RichText(
                  text: TextSpan(
                    text: 'Rambu',
                    style: GoogleFonts.oswald(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    children: [
                      TextSpan(
                        text: 'ID',
                        style: GoogleFonts.oswald(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 35),
          ],
        ),
        Positioned(
          bottom: 0,
          child: GestureDetector(
            onTap: () {
              _navigateWithTheme(
                DeteksiRambuPage(
                  currentThemeMode: widget.currentThemeMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Deteksi Rambu',
                    style: GoogleFonts.oswald(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    'assets/icons/ikon_webcam.png',
                    width: 24,
                    height: 24,
                    // color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainMenu({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap, // Tambahkan ini
  }) {
    return GestureDetector(
      onTap: onTap, // Tambahkan ini juga
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Center(child: Image.asset(icon, width: 40)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.oswald(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(
    String icon,
    String label, {
    required VoidCallback onTap,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        width: width ?? 150,
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(icon, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastDetectionCard() {
    if (_lastDetection == null) return const SizedBox();

    final label = _lastDetection!['label'] ?? 'Tidak diketahui';
    final timestampRaw = _lastDetection!['timestamp'];
    final timestamp = timestampRaw is Timestamp
        ? timestampRaw.toDate()
        : DateTime.tryParse(timestampRaw.toString()) ?? DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Image.asset('assets/icons/flaticon_rambu.png', width: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.oswald(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM, HH:mm WIB').format(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SizedBox(
        height: 300,
        child: FutureBuilder<List<FlSpot>>(
          future: getChartData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("Tidak ada data tersedia"));
            }

            double maxYValue = snapshot.data!.map((spot) => spot.y).reduce(max);
            maxYValue = maxYValue < 10 ? 10 : maxYValue + 2;

            return LineChart(
              LineChartData(
                minY: 0,
                maxY: maxYValue,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'Min',
                          'Sen',
                          'Sel',
                          'Rab',
                          'Kam',
                          'Jum',
                          'Sab',
                        ];
                        return Text(
                          days[value.toInt() % 7],
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: snapshot.data!,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserStatus() {
    final user = FirebaseAuth.instance.currentUser;
    return Row(
      children: [
        const Icon(Icons.person, size: 20, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          user?.email ?? 'Tidak ada akun',
          style: GoogleFonts.oswald(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}
