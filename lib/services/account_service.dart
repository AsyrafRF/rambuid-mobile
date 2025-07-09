// account_service.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AccountService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> deleteAccountWithPagination(BuildContext context) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final uid = currentUser.uid;
    late BuildContext dialogContext;

    // Tampilkan loading dialog non-dismissible
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Loading",
      pageBuilder: (_, _, _) {
        return Builder(
          builder: (ctx) {
            dialogContext = ctx;
            return const Center(child: CircularProgressIndicator());
          },
        );
      },
    );

    try {
      // Hapus subkoleksi 'detections' dengan paginasi batch
      const int batchLimit = 450;
      final detectionRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('detections');

      while (true) {
        final snapshot = await detectionRef.limit(batchLimit).get();
        if (snapshot.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Hapus dokumen user dan active_user
      final batchFinal = _firestore.batch();
      batchFinal.delete(_firestore.collection('users').doc(uid));
      batchFinal.delete(_firestore.collection('active_user').doc(uid));
      await batchFinal.commit();

      // Hapus akun dari FirebaseAuth
      try {
        await currentUser.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          Navigator.pop(dialogContext); // Tutup dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login ulang diperlukan untuk menghapus akun."),
            ),
          );
          await _auth.signOut();
          await Future.delayed(const Duration(milliseconds: 300));
          if (context.mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (_) => false);
          }
          return;
        } else {
          rethrow;
        }
      }

      // Hapus akun dari secure storage
      await _secureStorage.delete(key: uid);

      // Tutup dialog loading
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }

      // Tampilkan notifikasi sukses
      Fluttertoast.showToast(
        msg: "Akun berhasil dihapus",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Navigasi ke halaman login setelah delay
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }
      Fluttertoast.showToast(
        msg: "Gagal menghapus akun. Coba lagi.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
