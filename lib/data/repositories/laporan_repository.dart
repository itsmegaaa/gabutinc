import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/laporan_model.dart';

class LaporanRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================================================
  // REAL-TIME STREAMS
  // ==========================================================================

  Stream<List<LaporanModel>> streamLaporanByTahun(String tahun) {
    return _db
        .collection('laporan_$tahun')
        .orderBy('waktuUpdate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LaporanModel.fromFirestore(doc))
          // FIX MEDIUM: Hanya ambil data yang valid (bukan null)
          .whereType<LaporanModel>()
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
    try {
      // FIX MEDIUM (Security): Ambil URL Apps Script dengan aman dari Firestore
      final doc = await _db.collection('master_data').doc('config').get();

      if (!doc.exists || doc.data() == null) {
        throw Exception(
            'Dokumen konfigurasi sistem tidak ditemukan di database.');
      }

      final webAppUrl = doc.data()!['webAppUrl'] as String?;
      if (webAppUrl == null || webAppUrl.isEmpty) {
        throw Exception('URL Apps Script belum disetel di Firebase.');
      }

      // Gunakan URL yang didapat dari database
      await http.post(
        Uri.parse(webAppUrl),
        body: jsonEncode({'action': 'sync_from_firebase'}),
      );
    } catch (e) {
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('XMLHttpRequest error')) {
        debugPrint(
            'Abaikan error CORS. Eksekusi di Google Apps Script tetap berjalan.');

        await _db.collection('sync_metadata').doc('status').set(
            {'lastSyncToSheet': FieldValue.serverTimestamp()},
            SetOptions(merge: true));

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

  Future<void> tambahNotaris(String nama) async {
    await _db.collection('master_data').doc('notaris').set(
      {
        'items': FieldValue.arrayUnion([nama])
      },
      SetOptions(merge: true),
    );
  }

  Future<void> hapusNotaris(String nama) async {
    await _db.collection('master_data').doc('notaris').update(
      {
        'items': FieldValue.arrayRemove([nama])
      },
    );
  }

  Stream<DocumentSnapshot> streamMasterNotaris() {
    return _db.collection('master_data').doc('notaris').snapshots();
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

  // Stream data untuk list di layar Master Bank (Real-time)
  Stream<QuerySnapshot> streamMasterBank() {
    return _db.collection('master_bank').orderBy('namaBank').snapshots();
  }

  // Tambah Data Bank Baru
  Future<void> tambahBank(Map<String, dynamic> data) async {
    await _db.collection('master_bank').add(data);
  }

  // Update Data Bank
  Future<void> updateBank(String id, Map<String, dynamic> data) async {
    await _db.collection('master_bank').doc(id).update(data);
  }

  // Hapus Data Bank
  Future<void> hapusBank(String id) async {
    await _db.collection('master_bank').doc(id).delete();
  }
}
