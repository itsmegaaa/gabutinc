import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/laporan_model.dart';

class LaporanRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _webAppUrl =
      'https://script.google.com/macros/s/AKfycbxSUidflzOfoP7HpQ38bin186cmINe5gb2plMZi9CL716jv5dfK10w5hR78BftVMI0C/exec';

  // ==========================================================================
  // REAL-TIME STREAMS
  // ==========================================================================

  Stream<List<LaporanModel>> streamLaporanByTahun(String tahun) {
    return _db.collection('laporan_$tahun').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => LaporanModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<DocumentSnapshot> streamSyncStatus() {
    return _db.collection('sync_metadata').doc('status').snapshots();
  }

  Stream<QuerySnapshot> streamLogs() {
    return _db
        .collection('logs_laporan')
        .orderBy('waktu', descending: true)
        .limit(100)
        .snapshots();
  }

  // ==========================================================================
  // OPERASI CRUD LAPORAN
  // ==========================================================================

  Future<void> tambahLaporan(LaporanModel laporan) async {
    // Karena kita butuh ID dokumen sebelum menyimpan,
    // jika laporan.id kosong, kita generate dari Firestore.
    final docRef = laporan.id.isEmpty
        ? _db.collection('laporan_${laporan.tahun}').doc()
        : _db.collection('laporan_${laporan.tahun}').doc(laporan.id);

    final finalLaporan =
        laporan.id.isEmpty ? laporan.copyWith(id: docRef.id) : laporan;

    await docRef.set(finalLaporan.toMap());
  }

  Future<void> updateLaporan(LaporanModel laporan) async {
    await _db
        .collection('laporan_${laporan.tahun}')
        .doc(laporan.id)
        .update(laporan.toMap());
  }

  Future<void> hapusLaporan(String id, String tahun) async {
    await _db.collection('laporan_$tahun').doc(id).delete();
  }

  // ==========================================================================
  // SISTEM LOG AKTIVITAS
  // ==========================================================================

  Future<void> catatAktivitas(
      String aksi, String detail, String userEmail) async {
    await _db.collection('logs_laporan').add({
      'aksi': aksi,
      'detail': detail,
      'oleh': userEmail.isNotEmpty ? userEmail : 'Sistem',
      'waktu': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================================
  // SINKRONISASI MANUAL (APPS SCRIPT TRIGGER)
  // ==========================================================================

  Future<void> triggerSyncKeSheet() async {
    if (_webAppUrl.isEmpty) {
      throw Exception('URL Web App belum diatur');
    }

    try {
      await http.post(
        Uri.parse(_webAppUrl),
        body: jsonEncode({'action': 'sync_from_firebase'}),
      );
    } catch (e) {
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('XMLHttpRequest error')) {
        debugPrint(
            'Abaikan error CORS. Eksekusi di Google Apps Script tetap berjalan.');
        return;
      }

      rethrow;
    }
  }

  // ==========================================================================
  // MASTER DATA NOTARIS
  // ==========================================================================

  Future<List<String>> getMasterNotaris() async {
    final doc = await _db.collection('master_data').doc('notaris').get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data.containsKey('items')) {
        return List<String>.from(data['items']);
      }
    }
    return [];
  }

  // ==========================================================================
  // MASTER BANK
  // ==========================================================================
  Future<List<Map<String, dynamic>>> getMasterBank() async {
    try {
      final snapshot = await _db.collection('master_bank').get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'namaBank': doc.data()['namaBank'] ?? '',
                'namaPic': doc.data()['namaPic'] ?? '',
              })
          .toList();
    } catch (e) {
      debugPrint('Error get master bank: $e');
      return [];
    }
  }
}
