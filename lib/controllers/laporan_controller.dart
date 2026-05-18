import 'dart:async';
import 'package:flutter/material.dart';

import '../data/models/laporan_model.dart';
import '../data/repositories/laporan_repository.dart';

class LaporanController extends ChangeNotifier {
  final LaporanRepository _repo;

  // State Data
  List<LaporanModel> _semuaLaporan = [];
  List<LaporanModel> _laporanTerfilter = [];

  // State Filter & Pencarian
  String _tahunAktif = DateTime.now().year.toString();
  String _searchQuery = '';
  String _statusFilter = 'SEMUA';

  // State Stream & Memory Management
  StreamSubscription<List<LaporanModel>>? _streamSub;
  bool _isDisposed = false;
  bool _isLoading = true;

  LaporanController({required LaporanRepository repo}) : _repo = repo {
    mulaiListen();
  }

  // Getters
  List<LaporanModel> get dataLaporan => _laporanTerfilter;
  String get tahunAktif => _tahunAktif;
  String get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;

  // Statistik untuk HomeScreen (REVISI tanggalPelaksanaan)
  int get totalBulanIni {
    final sekarang = DateTime.now();
    final bulanIni = sekarang.month;
    final tahunIni = sekarang.year;

    return _semuaLaporan.where((l) {
      // HAPUS pengecekan == null dan tanda !
      if (l.tanggalPelaksanaan.isEmpty) return false;

      try {
        // HAPUS tanda ! di dalam parse
        final tgl = DateTime.parse(l.tanggalPelaksanaan);
        return tgl.month == bulanIni && tgl.year == tahunIni;
      } catch (e) {
        return false;
      }
    }).length;
  }

  int get totalBerkas => _semuaLaporan.length;
  int get totalBermasalah =>
      _semuaLaporan.where((l) => l.statusPekerjaan == 'BERMASALAH').length;
  int get totalProses =>
      _semuaLaporan.where((l) => l.statusPekerjaan == 'PROSES').length;
  int get totalPending =>
      _semuaLaporan.where((l) => l.statusPekerjaan == 'PENDING').length;

  void mulaiListen() {
    _isLoading = true;
    notifyListeners();

    _streamSub?.cancel();
    _streamSub = _repo.streamLaporanByTahun(_tahunAktif).listen(
      (snapshotData) {
        if (_isDisposed) return;
        _semuaLaporan = snapshotData;
        _terapkanFilterDanPencarian();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error mendengarkan stream laporan: $error');
        if (!_isDisposed) {
          _isLoading = false;
          notifyListeners();
        }
      },
    );
  }

  void ubahTahun(String tahunBaru) {
    if (_tahunAktif == tahunBaru) return;
    _tahunAktif = tahunBaru;
    mulaiListen();
  }

  void ubahFilterStatus(String status) {
    _statusFilter = status;
    _terapkanFilterDanPencarian();
    notifyListeners();
  }

  void cariLaporan(String query) {
    _searchQuery = query.toLowerCase();
    _terapkanFilterDanPencarian();
    notifyListeners();
  }

  void _terapkanFilterDanPencarian() {
    _laporanTerfilter = _semuaLaporan.where((laporan) {
      final cocokStatus =
          _statusFilter == 'SEMUA' || laporan.statusPekerjaan == _statusFilter;
      if (!cocokStatus) return false;

      if (_searchQuery.isNotEmpty) {
        final debitur = laporan.namaDebitur.toLowerCase();
        final bank = laporan.namaBank.toLowerCase();
        final covernote = laporan.noCovernote.toLowerCase();

        return debitur.contains(_searchQuery) ||
            bank.contains(_searchQuery) ||
            covernote.contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  Future<void> hapusData(
      String id, String namaDebitur, String userEmail) async {
    try {
      await _repo.hapusLaporan(id, _tahunAktif);
      await _repo.catatAktivitas(
          'HAPUS', 'Menghapus berkas debitur $namaDebitur', userEmail);
    } catch (e) {
      debugPrint('Gagal menghapus data: $e');
      rethrow;
    }
  }

  Future<void> triggerSyncManual(String userEmail) async {
    try {
      await _repo.catatAktivitas(
          'SYNC',
          'Meminta sinkronisasi manual ke Spreadsheet untuk data $_tahunAktif',
          userEmail);
      await _repo.triggerSyncKeSheet();
    } catch (e) {
      debugPrint('Gagal sync manual: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _streamSub?.cancel();
    super.dispose();
  }
}
