import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class RambuListPage extends StatefulWidget {
  final String initialFilterJenis;
  const RambuListPage({super.key, this.initialFilterJenis = 'Semua'});

  @override
  State<RambuListPage> createState() => _RambuListPageState();
}

class _RambuListPageState extends State<RambuListPage> {
  late String filterJenis;
  final jenisList = [
    'Semua',
    'Peringatan',
    'Larangan',
    'Petunjuk',
    'Informasi',
  ];
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    filterJenis = widget.initialFilterJenis; // Gunakan dari parameter
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance.collection('master_rambu');
    final stream = filterJenis == 'Semua'
        ? query.snapshots()
        : query.where('jenis', isEqualTo: filterJenis).snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange,
        title: const Text(
          'Daftar Rambu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: jenisList.length,
              itemBuilder: (context, index) {
                final jenis = jenisList[index];
                final selected = jenis == filterJenis;
                return GestureDetector(
                  onTap: () => setState(() => filterJenis = jenis),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      jenis,
                      style: TextStyle(
                        color: selected ? Colors.orange : Colors.black,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama rambu',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final nama = doc['nama'].toString().toLowerCase();
                  return nama.contains(searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text("Tidak ada data rambu."));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final nama = doc['nama'];
                    final iconBytes = base64Decode(doc['ikon_base64']);

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RambuDetailPage(doc: doc),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: Image.memory(iconBytes)),
                            const SizedBox(height: 8),
                            Text(
                              nama,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RambuDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const RambuDetailPage({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final nama = doc['nama'];
    final jenis = doc['jenis'];
    final deskripsi = doc['deskripsi'];
    final iconBytes = base64Decode(doc['ikon_base64']);
    final galeri =
        ((doc.data() as Map<String, dynamic>)['galeri'] ?? []) as List<dynamic>;
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> videoList = data['video_list'] ?? [];
    final videoUrl = data['video_url'];
    final String? videoId = videoUrl != null
        ? YoutubePlayer.convertUrlToId(videoUrl)
        : null;

    YoutubePlayerController? youtubeController;
    if (videoId != null) {
      youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }

    final List<YoutubePlayerController> videoControllers = videoList
        .map((url) {
          final videoId = YoutubePlayer.convertUrlToId(url);
          if (videoId != null) {
            return YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
            );
          }
          return null;
        })
        .whereType<YoutubePlayerController>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(nama, style: const TextStyle(fontSize: 20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.memory(iconBytes, height: 150)),
            const SizedBox(height: 20),
            Text("Jenis: $jenis", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              "Deskripsi:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(deskripsi),

            if (youtubeController != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Video Penjelasan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              YoutubePlayer(
                controller: youtubeController,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.orange,
              ),
            ],

            if (galeri.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Galeri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Column(
                children: galeri.map<Widget>((item) {
                  final imgBytes = base64Decode(item['ikon_base64']);
                  final caption = item['caption'];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(imgBytes),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ],

            if (videoControllers.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Video Tambahan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Column(
                children: videoControllers.map((controller) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: YoutubePlayer(
                      controller: controller,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: Colors.orange,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
