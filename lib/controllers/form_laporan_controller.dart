import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/laporan_model.dart';
import '../data/repositories/laporan_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormLaporanController extends ChangeNotifier {
  List<Map<String, dynamic>> _listMasterBank = [];
  List<Map<String, dynamic>> get listMasterBank => _listMasterBank;
  final LaporanRepository _repo;

  // ==========================================================================
  // TEXT EDITING CONTROLLERS (21 Field Input Murni)
  // ==========================================================================
  final TextEditingController namaDebiturCtrl = TextEditingController();
  final TextEditingController namaNotarisCtrl = TextEditingController();
  final TextEditingController namaBankCtrl = TextEditingController();
  final TextEditingController picBankCtrl = TextEditingController();
  final TextEditingController noSuratOrderCtrl = TextEditingController();
  final TextEditingController jenisCtrl = TextEditingController();
  final TextEditingController rincianOrderCtrl = TextEditingController();
  final TextEditingController noCovernoteCtrl = TextEditingController();
  final TextEditingController limitPlafonCtrl = TextEditingController();
  final TextEditingController nilaiHTCtrl = TextEditingController();
  final TextEditingController biayaNotarisCtrl = TextEditingController();
  final TextEditingController batasSlaCtrl = TextEditingController();
  final TextEditingController umurPekerjaanCtrl = TextEditingController();
  final TextEditingController progresDetailCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  final TextEditingController kekuranganCtrl = TextEditingController();
  final TextEditingController picInternalCtrl = TextEditingController();

  // ==========================================================================
  // STATE VARIABLES (Dropdown & Tanggal)
  // ==========================================================================
  String _statusPekerjaan = 'PROSES';
  DateTime? _tanggalOrder;
  DateTime? _tanggalPelaksanaan;
  DateTime? _tanggalBast;

  bool _isLoading = false;
  LaporanModel? _laporanAwal;
  String _tahunTarget = DateTime.now().year.toString();

  FormLaporanController({required LaporanRepository repo}) : _repo = repo;

  // Getters
  bool get isLoading => _isLoading;
  String get statusPekerjaan => _statusPekerjaan;
  DateTime? get tanggalOrder => _tanggalOrder;
  DateTime? get tanggalPelaksanaan => _tanggalPelaksanaan;
  DateTime? get tanggalBast => _tanggalBast;
  bool get isEditMode => _laporanAwal != null;

  // ==========================================================================
  // INISIALISASI FORM
  // ==========================================================================

// FIX MEDIUM: Ubah menjadi Future<void> dan async
  Future<void> initForm(
      {LaporanModel? laporanExisting, required String tahunAktif}) async {
    // 1. Nyalakan loading spinner di layar form
    _setLoading(true);

    _tahunTarget = tahunAktif;
    _laporanAwal = laporanExisting;

    // 2. TUNGGU master bank selesai diunduh dari database
    await muatMasterBank();

    if (laporanExisting != null) {
      namaDebiturCtrl.text = laporanExisting.namaDebitur;
      namaNotarisCtrl.text = laporanExisting.namaNotaris;
      namaBankCtrl.text = laporanExisting.namaBank;
      picBankCtrl.text = laporanExisting.picBank;
      noSuratOrderCtrl.text = laporanExisting.noSuratOrder;
      jenisCtrl.text = laporanExisting.jenis;
      rincianOrderCtrl.text = laporanExisting.rincianOrder;
      noCovernoteCtrl.text = laporanExisting.noCovernote;

      limitPlafonCtrl.text = _formatInputRupiah(laporanExisting.limitPlafon);
      nilaiHTCtrl.text = _formatInputRupiah(laporanExisting.nilaiHT);
      biayaNotarisCtrl.text = _formatInputRupiah(laporanExisting.biayaNotaris);

      batasSlaCtrl.text = laporanExisting.batasSla;
      umurPekerjaanCtrl.text = laporanExisting.umurPekerjaan;
      _statusPekerjaan = laporanExisting.statusPekerjaan.isEmpty
          ? 'PROSES'
          : laporanExisting.statusPekerjaan;
      progresDetailCtrl.text = laporanExisting.progresDetail;
      notesCtrl.text = laporanExisting.notes;
      kekuranganCtrl.text = laporanExisting.kekurangan;
      picInternalCtrl.text = laporanExisting.picInternal;

      _tanggalOrder = _parseDateOrNull(laporanExisting.tanggalOrder);
      _tanggalPelaksanaan =
          _parseDateOrNull(laporanExisting.tanggalPelaksanaan);
      _tanggalBast = _parseDateOrNull(laporanExisting.tanggalBast);
    } else {
      _bersihkanForm();
    }

    // 3. Matikan loading spinner agar form ditampilkan
    _setLoading(false);
  }

  DateTime? _parseDateOrNull(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Coba ISO 8601 dulu (format baru)
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    // Fallback: format lama dd-MM-yyyy
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3 && parts[2].length == 4) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}

    return null;
  }

  String _formatInputRupiah(String angkaStr) {
    if (angkaStr.isEmpty || angkaStr == '0') return '';
    final formatter =
        NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0);
    return formatter.format(int.parse(angkaStr)).trim();
  }

  // ==========================================================================
  // SETTERS UNTUK STATE NON-TEXTFIELD
  // ==========================================================================

  Future<void> setTanggalOrder(DateTime date) async {
    _tanggalOrder = date;
    _tanggalPelaksanaan = date;
    await _hitungBatasSla();
    _hitungUmurPekerjaan();
    notifyListeners();
  }

  void setTanggalPelaksanaan(DateTime date) {
    _tanggalPelaksanaan = date;
    notifyListeners();
  }

  void setTanggalBast(DateTime date) {
    _tanggalBast = date;
    setStatusPekerjaan(
        'SELESAI'); // Gunakan huruf kapital agar cocok dengan list
    notifyListeners();
  }

  void setStatusPekerjaan(String status) {
    _statusPekerjaan = status;
    notifyListeners();
  }

  void setNamaNotaris(String nama) {
    namaNotarisCtrl.text = nama;
  }

  // ==========================================================================
  // LOGIKA SIMPAN & DIFF CHECKER
  // ==========================================================================

  Future<bool> simpanData(String userEmail) async {
    if (namaDebiturCtrl.text.trim().isEmpty) return false;

    _setLoading(true);

    try {
      final cleanPlafon =
          limitPlafonCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanHT = nilaiHTCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanBiaya =
          biayaNotarisCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

      String formatTanggal(DateTime? date) {
        return date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
      }

      final laporanBaru = LaporanModel(
        id: isEditMode ? _laporanAwal!.id : '',
        tahun: isEditMode ? _laporanAwal!.tahun : _tahunTarget,
        namaDebitur: namaDebiturCtrl.text.trim(),
        namaNotaris: namaNotarisCtrl.text.trim(),
        namaBank: namaBankCtrl.text.trim(),
        picBank: picBankCtrl.text.trim(),
        noSuratOrder: noSuratOrderCtrl.text.trim(),
        tanggalOrder: formatTanggal(_tanggalOrder),
        jenis: jenisCtrl.text.trim(),
        rincianOrder: rincianOrderCtrl.text.trim(),
        noCovernote: noCovernoteCtrl.text.trim(),
        limitPlafon: cleanPlafon.isEmpty ? '0' : cleanPlafon,
        nilaiHT: cleanHT.isEmpty ? '0' : cleanHT,
        biayaNotaris: cleanBiaya.isEmpty ? '0' : cleanBiaya,
        tanggalPelaksanaan: formatTanggal(_tanggalPelaksanaan),
        batasSla: batasSlaCtrl.text.trim(),
        umurPekerjaan: umurPekerjaanCtrl.text.trim(),
        statusPekerjaan: _statusPekerjaan,
        progresDetail: progresDetailCtrl.text.trim(),
        tanggalBast: formatTanggal(_tanggalBast),
        notes: notesCtrl.text.trim(),
        kekurangan: kekuranganCtrl.text.trim(),
        picInternal: picInternalCtrl.text.trim(),
        updatedBy: userEmail,
        sudahSyncSheet: false,
      );

      if (!isEditMode) {
        await _repo.tambahLaporan(laporanBaru);
        await _repo.catatAktivitas(
          'TAMBAH',
          'Menambahkan data baru debitur ${laporanBaru.namaDebitur.toUpperCase()}',
          userEmail,
        );
      } else {
        await _repo.updateLaporan(laporanBaru);
        final diffMessage = _hitungDiff(_laporanAwal!, laporanBaru);
        await _repo.catatAktivitas(
          'EDIT',
          'Mengedit data ${laporanBaru.namaDebitur.toUpperCase()}. $diffMessage',
          userEmail,
        );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Gagal menyimpan data: $e');
      _setLoading(false);
      return false;
    }
  }

  String _hitungDiff(LaporanModel oldData, LaporanModel newData) {
    List<String> changes = [];

    if (oldData.namaDebitur.toUpperCase() != newData.namaDebitur.toUpperCase())
      changes.add('Debitur');
    if (oldData.namaNotaris != newData.namaNotaris) changes.add('Notaris');
    if (oldData.namaBank.toUpperCase() != newData.namaBank.toUpperCase())
      changes.add('KCU/KCP');
    if (oldData.picBank != newData.picBank) changes.add('PIC Bank');
    if (oldData.noSuratOrder != newData.noSuratOrder)
      changes.add('No Surat Order');
    if (oldData.tanggalOrder != newData.tanggalOrder) changes.add('Tgl Order');
    if (oldData.jenis != newData.jenis) changes.add('Jenis');
    if (oldData.rincianOrder != newData.rincianOrder)
      changes.add('Rincian Order');
    if (oldData.noCovernote.toUpperCase() != newData.noCovernote.toUpperCase())
      changes.add('No Covernote');
    if (oldData.limitPlafon != newData.limitPlafon) changes.add('Limit');
    if (oldData.nilaiHT != newData.nilaiHT) changes.add('Nilai HT');
    if (oldData.biayaNotaris != newData.biayaNotaris) changes.add('Biaya');
    if (oldData.tanggalPelaksanaan != newData.tanggalPelaksanaan)
      changes.add('Tgl Pelaksanaan');
    if (oldData.batasSla != newData.batasSla) changes.add('Batas SLA');
    if (oldData.umurPekerjaan != newData.umurPekerjaan)
      changes.add('Umur Pekerjaan');
    if (oldData.statusPekerjaan != newData.statusPekerjaan)
      changes.add('Progres Pekerjaan (Status)');
    if (oldData.progresDetail != newData.progresDetail)
      changes.add('Progres Terakhir');
    if (oldData.tanggalBast != newData.tanggalBast) changes.add('Tgl BAST');
    if (oldData.notes != newData.notes) changes.add('Per Kasus');
    if (oldData.kekurangan.toUpperCase() != newData.kekurangan.toUpperCase())
      changes.add('Kekurangan');
    if (oldData.picInternal != newData.picInternal) changes.add('PIC Internal');

    return changes.isEmpty
        ? '(Tanpa perubahan substansial)'
        : 'Update pada: ${changes.join(', ')}';
  }

  void _bersihkanForm() {
    namaDebiturCtrl.clear();
    namaNotarisCtrl.clear();
    namaBankCtrl.clear();
    picBankCtrl.clear();
    noSuratOrderCtrl.clear();
    jenisCtrl.clear();
    rincianOrderCtrl.clear();
    noCovernoteCtrl.clear();
    limitPlafonCtrl.clear();
    nilaiHTCtrl.clear();
    biayaNotarisCtrl.clear();
    batasSlaCtrl.clear();
    umurPekerjaanCtrl.clear();
    progresDetailCtrl.clear();
    notesCtrl.clear();
    kekuranganCtrl.clear();
    picInternalCtrl.clear();

    _statusPekerjaan = 'PROSES';
    _tanggalOrder = null;
    _tanggalPelaksanaan = null;
    _tanggalBast = null;
    _laporanAwal = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    namaDebiturCtrl.dispose();
    namaNotarisCtrl.dispose();
    namaBankCtrl.dispose();
    picBankCtrl.dispose();
    noSuratOrderCtrl.dispose();
    jenisCtrl.dispose();
    rincianOrderCtrl.dispose();
    noCovernoteCtrl.dispose();
    limitPlafonCtrl.dispose();
    nilaiHTCtrl.dispose();
    biayaNotarisCtrl.dispose();
    batasSlaCtrl.dispose();
    umurPekerjaanCtrl.dispose();
    progresDetailCtrl.dispose();
    notesCtrl.dispose();
    kekuranganCtrl.dispose();
    picInternalCtrl.dispose();
    super.dispose();
  }

  // Memuat data bank saat form dibuka
  Future<void> muatMasterBank() async {
    _listMasterBank = await _repo.getMasterBank();
    notifyListeners();
  }

  // Set nama bank & trigger auto-fill PIC
  void setNamaBankDanPic(String namaBank) {
    namaBankCtrl.text = namaBank;

    final bankDitemukan = _listMasterBank.firstWhere(
      (b) => b['namaBank'].toString().toLowerCase() == namaBank.toLowerCase(),
      orElse: () => {},
    );

    if (bankDitemukan.isNotEmpty &&
        bankDitemukan['namaPic'].toString().isNotEmpty) {
      picBankCtrl.text = bankDitemukan['namaPic'];
    }
    notifyListeners();
  }

  // Fungsi otomatis menghitung Batas SLA
  Future<void> _hitungBatasSla() async {
    if (_tanggalOrder == null) return;

    final prefs = await SharedPreferences.getInstance();
    final int targetSla = prefs.getInt('default_sla') ?? 30;

    final tanggalBatas = _tanggalOrder!.add(Duration(days: targetSla));

    // PERUBAHAN DISINI: Format diubah ke dd-MM-yyyy
    batasSlaCtrl.text = DateFormat('yyyy-MM-dd').format(tanggalBatas);

    notifyListeners();
  }

  // Fungsi otomatis menghitung Umur Pekerjaan dan Auto-Status
  void _hitungUmurPekerjaan() {
    if (_tanggalOrder != null) {
      final now = DateTime.now();
      final tglOrderSaja = DateTime(
          _tanggalOrder!.year, _tanggalOrder!.month, _tanggalOrder!.day);
      final hariIniSaja = DateTime(now.year, now.month, now.day);
      int selisihHari = hariIniSaja.difference(tglOrderSaja).inDays;
      if (selisihHari < 0) selisihHari = 0;

      umurPekerjaanCtrl.text = '$selisihHari Hari';

      // FIX: Hanya auto-set status jika ini mode TAMBAH BARU, bukan Edit
      if (!isEditMode &&
          statusPekerjaan != 'SELESAI' &&
          statusPekerjaan != 'BATAL') {
        if (selisihHari < 25) {
          setStatusPekerjaan('PROSES');
        } else if (selisihHari < 40) {
          setStatusPekerjaan('PENDING');
        } else {
          setStatusPekerjaan('BERMASALAH');
        }
      }
    }
  }
}
