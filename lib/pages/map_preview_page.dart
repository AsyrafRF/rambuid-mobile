import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPreviewPage extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? base64Icon; // Tambahan

  const MapPreviewPage({
    super.key,
    required this.latitude,
    required this.longitude,
    this.base64Icon,
  });

  @override
  Widget build(BuildContext context) {
    Widget markerWidget;

    if (base64Icon != null && base64Icon!.isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(base64Icon!);
        markerWidget = Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
        );
      } catch (e) {
        // Jika decoding gagal, fallback ke ikon default
        markerWidget = const Icon(
          Icons.location_on,
          size: 40,
          color: Colors.red,
        );
      }
    } else {
      markerWidget = const Icon(Icons.location_on, size: 40, color: Colors.red);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lokasi Deteksi')),
      body: FlutterMap(
        mapController: MapController(),
        options: MapOptions(
          initialCenter: LatLng(latitude, longitude),
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 50,
                height: 50,
                alignment: Alignment.topCenter,
                child: markerWidget,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
