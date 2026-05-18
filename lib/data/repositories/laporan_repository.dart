import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../core/utils/web_sync_launcher.dart';
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

  Future<void> triggerSyncKeSheet(String tahun) async {
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

      if (kIsWeb) {
        await _sendWebSyncRequest(webAppUrl, tahun);
        return;
      }

      final response = await _sendSyncRequest(webAppUrl, tahun);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Apps Script gagal merespons sync (${response.statusCode}): ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
        final message = decoded is Map<String, dynamic>
            ? decoded['message'] ?? response.body
            : response.body;
        throw Exception('Apps Script gagal sync: $message');
      }
    } catch (e) {
      if (kIsWeb &&
          (e.toString().contains('Failed to fetch') ||
              e.toString().contains('XMLHttpRequest error'))) {
        throw Exception(
            'Request ke Apps Script gagal/CORS. Cek Apps Script Executions untuk memastikan sync berjalan.');
      }

      rethrow;
    }
  }

  Future<void> _sendWebSyncRequest(String webAppUrl, String tahun) async {
    final before = await _db.collection('sync_metadata').doc('status').get();
    final beforeLastSync = _timestampMillis(before.data()?['lastSyncToSheet']);
    final beforeError = before.data()?['syncError'] as String?;

    final syncUrl = _buildSyncGetUri(webAppUrl, tahun).toString();
    await launchAppsScriptSync(syncUrl);

    final deadline = DateTime.now().add(const Duration(seconds: 90));

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));

      final statusDoc =
          await _db.collection('sync_metadata').doc('status').get();
      final data = statusDoc.data();
      if (data == null) continue;

      final syncError = data['syncError'] as String?;
      if (syncError != null &&
          syncError.trim().isNotEmpty &&
          syncError != beforeError) {
        throw Exception('Apps Script gagal sync: $syncError');
      }

      final statusTahun = data['tahun']?.toString();
      final lastSync = _timestampMillis(data['lastSyncToSheet']);
      final isDone = data['isSyncing'] == false &&
          statusTahun == tahun &&
          lastSync != null &&
          lastSync != beforeLastSync;

      if (isDone) return;
    }

    throw Exception(
        'Request sync sudah dikirim, tetapi status sukses belum terkonfirmasi. Cek Apps Script Executions.');
  }

  Future<http.Response> _sendSyncRequest(String webAppUrl, String tahun) {
    final uri = Uri.parse(webAppUrl);

    return http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'sync_from_firebase',
            'tahun': tahun,
          }),
        )
        .timeout(const Duration(seconds: 60));
  }

  Uri _buildSyncGetUri(String webAppUrl, String tahun) {
    final uri = Uri.parse(webAppUrl);
    final query = Map<String, String>.from(uri.queryParameters)
      ..['action'] = 'sync_from_firebase'
      ..['tahun'] = tahun;

    return uri.replace(queryParameters: query);
  }

  int? _timestampMillis(Object? value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return null;
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
