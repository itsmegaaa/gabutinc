import 'package:cloud_firestore/cloud_firestore.dart';

class LaporanModel {
  final String id;
  final String tahun;

  // 21 Kolom Data Sesuai Spreadsheet
  final String namaDebitur;
  final String namaNotaris;
  final String namaBank;
  final String picBank;
  final String noSuratOrder;
  final String tanggalOrder;
  final String jenis;
  final String rincianOrder;
  final String noCovernote;
  final String limitPlafon;
  final String nilaiHT;
  final String biayaNotaris;
  final String tanggalPelaksanaan;
  final String batasSla;
  final String umurPekerjaan;
  final String statusPekerjaan;
  final String progresDetail;
  final String tanggalBast;
  final String notes;
  final String kekurangan;
  final String picInternal;

  // Metadata Sistem
  final DateTime? waktuUpdate;
  final String updatedBy;
  final bool sudahSyncSheet;

  LaporanModel({
    required this.id,
    required this.tahun,
    required this.namaDebitur,
    required this.namaNotaris,
    required this.namaBank,
    required this.picBank,
    required this.noSuratOrder,
    required this.tanggalOrder,
    required this.jenis,
    required this.rincianOrder,
    required this.noCovernote,
    required this.limitPlafon,
    required this.nilaiHT,
    required this.biayaNotaris,
    required this.tanggalPelaksanaan,
    required this.batasSla,
    required this.umurPekerjaan,
    required this.statusPekerjaan,
    required this.progresDetail,
    required this.tanggalBast,
    required this.notes,
    required this.kekurangan,
    required this.picInternal,
    this.waktuUpdate,
    required this.updatedBy,
    required this.sudahSyncSheet,
  });

  static LaporanModel? fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Jika data kosong, kembalikan null saja, jangan di-throw!
    if (data == null) return null;

    return LaporanModel.fromMap(data, doc.id);
  }

  factory LaporanModel.fromMap(Map<String, dynamic> map, String id) {
    return LaporanModel(
      id: id,
      tahun: map['tahun'] as String? ?? '',
      namaDebitur: map['namaDebitur'] as String? ?? '',
      namaNotaris: map['namaNotaris'] as String? ?? '',
      namaBank: map['namaBank'] as String? ?? '',
      picBank: map['picBank'] as String? ?? '',
      noSuratOrder: map['noSuratOrder'] as String? ?? '',
      tanggalOrder: map['tanggalOrder'] as String? ?? '',
      jenis: map['jenis'] as String? ?? '',
      rincianOrder: map['rincianOrder'] as String? ?? '',
      noCovernote: map['noCovernote'] as String? ?? '',
      limitPlafon: map['limitPlafon'] as String? ?? '0',
      nilaiHT: map['nilaiHT'] as String? ?? '0',
      biayaNotaris: map['biayaNotaris'] as String? ?? '0',
      tanggalPelaksanaan: map['tanggalPelaksanaan'] as String? ?? '',
      batasSla: map['batasSla'] as String? ?? '',
      umurPekerjaan: map['umurPekerjaan'] as String? ?? '',
      statusPekerjaan: map['statusPekerjaan'] as String? ?? '',
      progresDetail: map['progresDetail'] as String? ?? '',
      tanggalBast: map['tanggalBast'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      kekurangan: map['kekurangan'] as String? ?? '',
      picInternal: map['picInternal'] as String? ?? '',
      waktuUpdate: map['waktuUpdate'] != null
          ? (map['waktuUpdate'] as Timestamp).toDate()
          : null,
      updatedBy: map['updatedBy'] as String? ?? '',
      sudahSyncSheet: map['sudahSyncSheet'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tahun': tahun,
      'namaDebitur': namaDebitur.toUpperCase(),
      'namaNotaris': namaNotaris,
      'namaBank': namaBank.toUpperCase(),
      'picBank': picBank,
      'noSuratOrder': noSuratOrder,
      'tanggalOrder': tanggalOrder,
      'jenis': jenis,
      'rincianOrder': rincianOrder,
      'noCovernote': noCovernote.toUpperCase(),
      'limitPlafon': limitPlafon,
      'nilaiHT': nilaiHT,
      'biayaNotaris': biayaNotaris,
      'tanggalPelaksanaan': tanggalPelaksanaan,
      'batasSla': batasSla,
      'umurPekerjaan': umurPekerjaan,
      'statusPekerjaan': statusPekerjaan,
      'progresDetail': progresDetail,
      'tanggalBast': tanggalBast,
      'notes': notes,
      'kekurangan': kekurangan.toUpperCase(),
      'picInternal': picInternal,
      'waktuUpdate': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'sudahSyncSheet': sudahSyncSheet,
    };
  }

  LaporanModel copyWith({
    String? id,
    String? tahun,
    String? namaDebitur,
    String? namaNotaris,
    String? namaBank,
    String? picBank,
    String? noSuratOrder,
    String? tanggalOrder,
    String? jenis,
    String? rincianOrder,
    String? noCovernote,
    String? limitPlafon,
    String? nilaiHT,
    String? biayaNotaris,
    String? tanggalPelaksanaan,
    String? batasSla,
    String? umurPekerjaan,
    String? statusPekerjaan,
    String? progresDetail,
    String? tanggalBast,
    String? notes,
    String? kekurangan,
    String? picInternal,
    DateTime? waktuUpdate,
    String? updatedBy,
    bool? sudahSyncSheet,
  }) {
    return LaporanModel(
      id: id ?? this.id,
      tahun: tahun ?? this.tahun,
      namaDebitur: namaDebitur ?? this.namaDebitur,
      namaNotaris: namaNotaris ?? this.namaNotaris,
      namaBank: namaBank ?? this.namaBank,
      picBank: picBank ?? this.picBank,
      noSuratOrder: noSuratOrder ?? this.noSuratOrder,
      tanggalOrder: tanggalOrder ?? this.tanggalOrder,
      jenis: jenis ?? this.jenis,
      rincianOrder: rincianOrder ?? this.rincianOrder,
      noCovernote: noCovernote ?? this.noCovernote,
      limitPlafon: limitPlafon ?? this.limitPlafon,
      nilaiHT: nilaiHT ?? this.nilaiHT,
      biayaNotaris: biayaNotaris ?? this.biayaNotaris,
      tanggalPelaksanaan: tanggalPelaksanaan ?? this.tanggalPelaksanaan,
      batasSla: batasSla ?? this.batasSla,
      umurPekerjaan: umurPekerjaan ?? this.umurPekerjaan,
      statusPekerjaan: statusPekerjaan ?? this.statusPekerjaan,
      progresDetail: progresDetail ?? this.progresDetail,
      tanggalBast: tanggalBast ?? this.tanggalBast,
      notes: notes ?? this.notes,
      kekurangan: kekurangan ?? this.kekurangan,
      picInternal: picInternal ?? this.picInternal,
      waktuUpdate: waktuUpdate ?? this.waktuUpdate,
      updatedBy: updatedBy ?? this.updatedBy,
      sudahSyncSheet: sudahSyncSheet ?? this.sudahSyncSheet,
    );
  }
}
