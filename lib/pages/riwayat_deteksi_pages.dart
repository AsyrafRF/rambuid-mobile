import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'daftar_rambu_pages.dart';
import 'map_preview_page.dart';

// Tetap sama: semua import kamu

class DetectionHistoryPage extends StatefulWidget {
  const DetectionHistoryPage({super.key});

  @override
  State<DetectionHistoryPage> createState() => _DetectionHistoryPageState();
}

class _DetectionHistoryPageState extends State<DetectionHistoryPage> {
  final bool _stretch = true;
  DateTime? _lastRefresh;
  bool _checkingLoginStatus = true;
  bool _isNavigating = false;

  // PAGINATION
  final int _limit = 10;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  List<DocumentSnapshot> _detectionDocs = [];

  final ScrollController _scrollController = ScrollController();

  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn().then((_) async {
      setState(() => _checkingLoginStatus = false);
      await _loadInitialData();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _loadMoreData();
      }
    });
  }

  Query _buildQuery({bool isInitial = true}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return FirebaseFirestore.instance.collection('x'); // dummy
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('detections')
        .orderBy('timestamp', descending: true); // masih bisa sort karena ISO

    if (!isInitial && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query.limit(_limit);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _detectionDocs.clear();
        _lastDocument = null;
        _hasMore = true;
      });
      await _loadInitialData();
    }
  }

  Future<void> _checkIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.providerData.isEmpty) {
      _redirectToLogin();
      return;
    }

    final allowedProviders = ['google.com', 'password'];
    final isAllowed = user.providerData.any(
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
            "Anda harus login menggunakan akun Google atau Email/Password.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text("Login Sekarang"),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _lastRefresh = DateTime.now();
      _detectionDocs.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialData();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Disegarkan!')));
  }

  Future<void> _loadInitialData() async {
    final querySnapshot = await _buildQuery().get();

    List<DocumentSnapshot> allDocs = querySnapshot.docs;

    if (_selectedDate != null) {
      final startOfDay = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      allDocs = allDocs.where((doc) {
        final ts = doc['timestamp'];
        if (ts is String) {
          final parsedTime = DateTime.tryParse(ts);
          if (parsedTime != null) {
            return parsedTime.isAfter(
                  startOfDay.subtract(const Duration(seconds: 1)),
                ) &&
                parsedTime.isBefore(endOfDay);
          }
        }
        return false;
      }).toList();
    }

    setState(() {
      _detectionDocs = allDocs;
      _lastDocument = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;
      _hasMore = querySnapshot.docs.length == _limit;
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final query = await _buildQuery(isInitial: false).get();

    if (query.docs.isNotEmpty) {
      setState(() {
        _detectionDocs.addAll(query.docs);
        _lastDocument = query.docs.last;
        _hasMore = query.docs.length == _limit;
      });
    } else {
      setState(() => _hasMore = false);
    }

    setState(() => _isLoadingMore = false);
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      stretch: _stretch,
      onStretchTrigger: _refreshData,
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
                offset: Offset(0, 2),
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
            Container(),
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

  Widget _buildDateFilter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ElevatedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(
            _selectedDate == null
                ? 'Pilih Tanggal'
                : DateFormat(
                    'EEEE, d MMMM yyyy',
                    'id_ID',
                  ).format(_selectedDate!),
          ),
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

    final String formattedTime = DateFormat.yMMMd().add_jm().format(
      dateTime.toLocal(),
    );
    final int x1 = (doc['x1'] as num?)?.toInt() ?? 0;
    final int y1 = (doc['y1'] as num?)?.toInt() ?? 0;
    final int x2 = (doc['x2'] as num?)?.toInt() ?? 0;
    final int y2 = (doc['y2'] as num?)?.toInt() ?? 0;
    final String? base64Image = doc['image_base64'];

    // Tambahan: lokasi dan orientasi
    final Map<String, dynamic> orientasi =
        doc.data().toString().contains('orientasi') && doc['orientasi'] != null
        ? Map<String, dynamic>.from(doc['orientasi'])
        : {};
    final Map<String, dynamic> lokasi =
        doc.data().toString().contains('lokasi') && doc['lokasi'] != null
        ? Map<String, dynamic>.from(doc['lokasi'])
        : {};

    final Map<String, dynamic> accel =
        (orientasi['accel'] as Map?)?.cast<String, dynamic>() ?? {};
    final Map<String, dynamic> gyro =
        (orientasi['gyro'] as Map?)?.cast<String, dynamic>() ?? {};

    final double lat = lokasi['lat']?.toDouble() ?? 0;
    final double lon = lokasi['lon']?.toDouble() ?? 0;

    String formatVector(Map<String, dynamic> v, String unit) {
      return 'X=${v['x']?.toStringAsFixed(2)}$unit, '
          'Y=${v['y']?.toStringAsFixed(2)}$unit, '
          'Z=${v['z']?.toStringAsFixed(2)}$unit';
    }

    String formatKoordinat(
      double value, {
      String arahPositif = 'N',
      String arahNegatif = 'S',
    }) {
      final arah = value >= 0 ? arahPositif : arahNegatif;
      return '${value.abs().toStringAsFixed(4)}° $arah';
    }

    // Pemakaian:
    final accelStr = formatVector(accel, ' m/s²');
    final gyroStr = formatVector(gyro, ' °/s');
    final String latStr = formatKoordinat(
      lat,
      arahPositif: 'N',
      arahNegatif: 'S',
    );
    final String lonStr = formatKoordinat(
      lon,
      arahPositif: 'E',
      arahNegatif: 'W',
    );

    Future<void> navigateToRambuDetail(String label) async {
      if (_isNavigating) return; // Hindari double tap
      setState(() => _isNavigating = true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final query = await FirebaseFirestore.instance
          .collection('master_rambu')
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? matchingDoc;

      for (final doc in query.docs) {
        final nama = (doc['nama'] as String?)?.toLowerCase();
        if (nama == label.toLowerCase()) {
          matchingDoc = doc;
          break;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading overlay
      setState(() => _isNavigating = false);

      if (matchingDoc != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RambuDetailPage(doc: matchingDoc!)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rambu "$label" tidak ditemukan di master.')),
        );
      }
    }

    void showDetailRambuDialog(String label) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Lihat Detail Rambu"),
          content: Text("Ingin melihat detail rambu \"$label\"?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog dulu
                await navigateToRambuDetail(label);
              },
              child: const Text("Lihat"),
            ),
          ],
        ),
      );
    }

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (lokasi['lat'] != null &&
                    lokasi['lon'] != null &&
                    lokasi['lat'] is num &&
                    lokasi['lon'] is num)
                  GestureDetector(
                    onTap: () async {
                      final lat = (lokasi['lat'] as num).toDouble();
                      final lng = (lokasi['lon'] as num).toDouble();

                      final masterQuery = await FirebaseFirestore.instance
                          .collection('master_rambu')
                          .get();

                      final _ = label.toLowerCase();

                      String normalize(String input) =>
                          input.trim().toLowerCase();

                      final matchingDocs = masterQuery.docs.where((doc) {
                        final nama = doc.data()['nama'];
                        return nama is String &&
                            normalize(nama) == normalize(label);
                      }).toList();

                      final matchingDoc = matchingDocs.isNotEmpty
                          ? matchingDocs.first
                          : null;

                      if (matchingDoc == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Rambu "$label" tidak ditemukan di master.',
                            ),
                          ),
                        );
                      }

                      final String? base64Icon = matchingDoc
                          ?.data()['image_base64'];

                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPreviewPage(
                            latitude: lat,
                            longitude: lng,
                            base64Icon: base64Icon,
                          ),
                        ),
                      );

                    },
                    child: Chip(
                      avatar: const Icon(
                        Icons.place,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        '$latStr, $lonStr',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.place, color: Colors.white, size: 18),
                    label: Text(
                      'Lokasi tidak diketahui',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                if (orientasi.isNotEmpty)
                  Chip(
                    avatar: const Icon(
                      Icons.explore,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      '$accelStr, $gyroStr',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (base64Image != null && base64Image.isNotEmpty)
              GestureDetector(
                onTap: () => showDetailRambuDialog(label),
                child: Image.memory(
                  base64Decode(base64Image),
                  height: 200,
                  fit: BoxFit.cover,
                ),
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

  Widget _buildPaginatedList() {
    if (_detectionDocs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
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

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < _detectionDocs.length) {
          return _buildDetectionItem(_detectionDocs[index]);
        } else if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        } else {
          return const SizedBox(height: 80);
        }
      }, childCount: _detectionDocs.length + (_isLoadingMore ? 1 : 0)),
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
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildDateFilter(), // tambahkan ini
            _buildPaginatedList(),
          ],
        ),
      ),
    );
  }
}
