// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rambu_idv2/pages/riwayat_deteksi_pages.dart';
import 'daftar_rambu_pages.dart';
import 'deteksi_pages.dart';
import 'profil_page.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  _BerandaPageState createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  int _currentIndex = 0;
  bool _isSnackbarShown = false; // Mencegah snackbar muncul berulang

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeteksiRambuPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RambuListPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DetectionHistoryPage()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilPage()),
      );
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              _buildLogoWithButton(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMainMenu(
                    icon: 'assets/icons/ikon_daftar_rambu.png',
                    label: 'Daftar Rambu',
                    color: const Color(0xFFFFF3DD),
                  ),
                  _buildMainMenu(
                    icon: 'assets/icons/ikon_riwayat_rambu.png',
                    label: 'Riwayat Rambu',
                    color: const Color(0xFFFFF3DD),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_peringatan.png',
                    'Rambu Peringatan',
                  ),
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_larangan.png',
                    'Rambu Larangan',
                  ),
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_petunjuk.png',
                    'Rambu Petunjuk',
                  ),
                  _buildCategoryButton(
                    'assets/icons/ikon_rambu_informasi.png',
                    'Rambu Informasi',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Riwayat Rambu',
                  style: GoogleFonts.oswald(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Image.asset('assets/icons/ikon_bus.png', width: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pemberhentian Bus',
                            style: GoogleFonts.oswald(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '14 Mar, 15.30 WIB • Live Camera',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              icon: Icon(Icons.folder),
              label: 'Database',
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DeteksiRambuPage(),
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
  }) {
    return Column(
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
          style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String icon, String label) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
