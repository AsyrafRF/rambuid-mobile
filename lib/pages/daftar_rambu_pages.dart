import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RambuListPage extends StatefulWidget {
  const RambuListPage({super.key});

  @override
  State<RambuListPage> createState() => _RambuListPageState();
}

class _RambuListPageState extends State<RambuListPage> {
  String filterJenis = 'Semua';
  final jenisList = ['Semua', 'Peringatan', 'Larangan', 'Petunjuk', 'Informasi'];
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      jenis,
                      style: TextStyle(
                        color: selected ? Colors.orange : Colors.black,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
                        MaterialPageRoute(builder: (_) => RambuDetailPage(doc: doc)),
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
                            Expanded(
                              child: Image.memory(iconBytes),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nama,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

    return Scaffold(
      appBar: AppBar(title: Text(nama)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.memory(iconBytes, height: 150),
            ),
            const SizedBox(height: 20),
            Text("Jenis: $jenis", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            const Text("Deskripsi:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(deskripsi),
          ],
        ),
      ),
    );
  }
}



