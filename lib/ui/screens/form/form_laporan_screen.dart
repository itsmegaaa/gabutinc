import 'dart:ui'; // Tambahan wajib untuk efek blur kaca (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/globals.dart';
import '../../../controllers/form_laporan_controller.dart';
import '../../../controllers/user_provider.dart';
import '../../../data/repositories/laporan_repository.dart';

class FormLaporanScreen extends StatefulWidget {
  const FormLaporanScreen({Key? key}) : super(key: key);

  @override
  State<FormLaporanScreen> createState() => _FormLaporanScreenState();
}

class _FormLaporanScreenState extends State<FormLaporanScreen> {
  final _formKey = GlobalKey<FormState>();
  List<String> _listNotaris = [];

  @override
  void initState() {
    super.initState();
    _muatMasterNotaris();
  }

  Future<void> _muatMasterNotaris() async {
    final repo = context.read<LaporanRepository>();
    final data = await repo.getMasterNotaris();
    setState(() {
      _listNotaris = data;
    });
  }

  // Helper Pemilihan Tanggal
  Future<void> _pilihTanggal(BuildContext context, DateTime? initialDate,
      Function(DateTime) onSelected) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        // Disesuaikan agar kalender tampil elegan di tema gelap
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppConstants.goldColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      onSelected(pickedDate);
    }
  }

  void _simpan(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final userProv = context.read<UserProvider>();
    final ctrl = context.read<FormLaporanController>();

    FocusScope.of(context).unfocus();

    final sukses = await ctrl.simpanData(userProv.email);

    if (sukses && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data berhasil disimpan!'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Gagal menyimpan data. Periksa koneksi internet Anda.'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FormLaporanController>();

    return Scaffold(
      extendBodyBehindAppBar: true, // Biarkan background memanjang ke atas
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar Transparan
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          ctrl.isEditMode ? 'EDIT LAPORAN' : 'TAMBAH LAPORAN',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // =========================================================
          // BACKGROUND DARK GRADIENT (Glassmorphism Base)
          // =========================================================
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
              ),
            ),
          ),

          SafeArea(
            child: ctrl.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppConstants.goldColor))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // =========================================================
                          // BAGIAN 1: INFORMASI UMUM
                          // =========================================================
                          _buildGlassSection(
                            title: 'INFORMASI UMUM',
                            icon: Icons.person_outline,
                            children: [
                              _buildLabel('Nama Debitur (Wajib)'),
                              _buildGlassField(
                                controller: ctrl.namaDebiturCtrl,
                                hint: 'Masukkan nama debitur',
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Tidak boleh kosong'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Nama Notaris'),
                              Autocomplete<String>(
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty)
                                    return const Iterable<String>.empty();
                                  return _listNotaris.where((option) => option
                                      .toLowerCase()
                                      .contains(
                                          textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (String selection) =>
                                    ctrl.setNamaNotaris(selection),
                                fieldViewBuilder: (context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted) {
                                  if (ctrl.namaNotarisCtrl.text.isNotEmpty &&
                                      textEditingController.text.isEmpty) {
                                    textEditingController.text =
                                        ctrl.namaNotarisCtrl.text;
                                  }
                                  return _buildGlassField(
                                    controller: textEditingController,
                                    hint: 'Pilih atau ketik nama notaris',
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      ctrl.namaNotarisCtrl.text = val;
                                    },
                                  );
                                },
                                // UI Custom agar Dropdown Autocomplete berwarna gelap
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      color: const Color(0xFF1E293B),
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(15),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width -
                                                80,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8.0),
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            final String option =
                                                options.elementAt(index);
                                            return ListTile(
                                              title: Text(option,
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('KCU/KCP (Bank)'),
                              Autocomplete<Map<String, dynamic>>(
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<
                                        Map<String, dynamic>>.empty();
                                  }
                                  return ctrl.listMasterBank.where((option) {
                                    final namaBank = option['namaBank']
                                        .toString()
                                        .toLowerCase();
                                    return namaBank.contains(
                                        textEditingValue.text.toLowerCase());
                                  });
                                },
                                displayStringForOption: (option) =>
                                    option['namaBank'] as String,
                                onSelected: (selection) =>
                                    ctrl.setNamaBankDanPic(
                                        selection['namaBank'] as String),
                                fieldViewBuilder: (context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted) {
                                  if (ctrl.namaBankCtrl.text.isNotEmpty &&
                                      textEditingController.text.isEmpty) {
                                    textEditingController.text =
                                        ctrl.namaBankCtrl.text;
                                  }
                                  return _buildGlassField(
                                    controller: textEditingController,
                                    hint: 'Ketik nama KCU/KCP Bank...',
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      ctrl.namaBankCtrl.text = val;
                                    },
                                  );
                                },
                                // UI Custom agar Dropdown Autocomplete berwarna gelap
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      color: const Color(0xFF1E293B),
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(15),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width -
                                                80,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8.0),
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            final option =
                                                options.elementAt(index);
                                            return ListTile(
                                              title: Text(option['namaBank'],
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                              subtitle: Text(
                                                  'PIC: ${option['namaPic']}',
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.5),
                                                      fontSize: 12)),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('PIC Bank'),
                              _buildGlassField(
                                controller: ctrl.picBankCtrl,
                                hint: 'Nama PIC Bank terkait',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // =========================================================
                          // BAGIAN 2: DETAIL ORDER
                          // =========================================================
                          _buildGlassSection(
                            title: 'DETAIL ORDER',
                            icon: Icons.assignment_outlined,
                            children: [
                              _buildLabel('No. Surat Order'),
                              _buildGlassField(
                                controller: ctrl.noSuratOrderCtrl,
                                hint: 'R06.UM.GKD/0004/2026',
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Tanggal Order'),
                              InkWell(
                                onTap: () => _pilihTanggal(
                                    context,
                                    ctrl.tanggalOrder,
                                    (dt) async =>
                                        await ctrl.setTanggalOrder(dt)),
                                child: InputDecorator(
                                  decoration: _glassInputDecoration(
                                      'Pilih tanggal order',
                                      suffixIcon: Icons.calendar_month),
                                  child: Text(
                                    ctrl.tanggalOrder != null
                                        ? DateFormat('dd MMM yyyy')
                                            .format(ctrl.tanggalOrder!)
                                        : 'Pilih tanggal order',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: ctrl.tanggalOrder != null
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Jenis'),
                              DropdownButtonFormField<String>(
                                value: ['Hak Tanggungan', 'Lainnya', 'Fidusia']
                                        .contains(ctrl.jenisCtrl.text)
                                    ? ctrl.jenisCtrl.text
                                    : null,
                                hint: Text('Pilih jenis order',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 14)),
                                isExpanded: true,
                                decoration: _glassInputDecoration(''),
                                dropdownColor: const Color(0xFF1E293B),
                                iconEnabledColor: Colors.white54,
                                items: ['Hak Tanggungan', 'Lainnya', 'Fidusia']
                                    .map((String val) {
                                  return DropdownMenuItem(
                                    value: val,
                                    child: Text(val,
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) ctrl.jenisCtrl.text = val;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Rincian Order'),
                              _buildGlassField(
                                controller: ctrl.rincianOrderCtrl,
                                hint: 'SHM No. 00037/Desa Mekarbakti...',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('No. Covernote'),
                              _buildGlassField(
                                controller: ctrl.noCovernoteCtrl,
                                hint: 'XX/NTR/X/20XX',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // =========================================================
                          // BAGIAN 3: FINANSIAL
                          // =========================================================
                          _buildGlassSection(
                            title: 'FINANSIAL',
                            icon: Icons.monetization_on_outlined,
                            children: [
                              _buildLabel('Limit / Plafon'),
                              _buildGlassField(
                                controller: ctrl.limitPlafonCtrl,
                                hint: '0',
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyFormatIdr()],
                                prefixText: 'Rp ',
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Nilai HT'),
                              _buildGlassField(
                                controller: ctrl.nilaiHTCtrl,
                                hint: '0',
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyFormatIdr()],
                                prefixText: 'Rp ',
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Biaya Notaris'),
                              _buildGlassField(
                                controller: ctrl.biayaNotarisCtrl,
                                hint: '0',
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyFormatIdr()],
                                prefixText: 'Rp ',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // =========================================================
                          // BAGIAN 4: PELAKSANAAN & SLA
                          // =========================================================
                          _buildGlassSection(
                            title: 'PELAKSANAAN & SLA',
                            icon: Icons.timer_outlined,
                            children: [
                              _buildLabel('Tanggal Pelaksanaan'),
                              InputDecorator(
                                decoration: _glassInputDecoration(
                                    'Otomatis mengikuti Tanggal Order',
                                    suffixIcon: Icons.lock_outline),
                                child: Text(
                                  ctrl.tanggalPelaksanaan != null
                                      ? DateFormat('dd MMM yyyy')
                                          .format(ctrl.tanggalPelaksanaan!)
                                      : 'Otomatis mengikuti Tanggal Order',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: ctrl.tanggalPelaksanaan != null
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Batas SLA Laporan'),
                              IgnorePointer(
                                child: _buildGlassField(
                                  controller: ctrl.batasSlaCtrl,
                                  hint:
                                      'Dihitung otomatis (Tgl Pelaksanaan + SLA)',
                                  suffixIcon: Icons.lock_outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Umur Pekerjaan'),
                              IgnorePointer(
                                child: _buildGlassField(
                                  controller: ctrl.umurPekerjaanCtrl,
                                  hint:
                                      'Dihitung otomatis (Hari Ini - Tgl Order)',
                                  suffixIcon: Icons.lock_outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // =========================================================
                          // BAGIAN 5: PROGRES & BAST
                          // =========================================================
                          _buildGlassSection(
                            title: 'PROGRES & BAST',
                            icon: Icons.trending_up_rounded,
                            children: [
                              _buildLabel('Progres Pekerjaan (Status)'),
                              DropdownButtonFormField<String>(
                                value: AppConstants.listStatusPekerjaan
                                        .contains(ctrl.statusPekerjaan)
                                    ? ctrl.statusPekerjaan
                                    : null,
                                hint: Text('Pilih Status',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 14)),
                                isExpanded: true,
                                decoration: _glassInputDecoration(''),
                                dropdownColor: const Color(0xFF1E293B),
                                iconEnabledColor: Colors.white54,
                                items: AppConstants.listStatusPekerjaan
                                    .map((String val) {
                                  return DropdownMenuItem(
                                    value: val,
                                    child: Text(val,
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) ctrl.setStatusPekerjaan(val);
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Progres Terakhir / Keterangan'),
                              _buildGlassField(
                                controller: ctrl.progresDetailCtrl,
                                hint: 'Contoh: SKMHT, Selesai Cetak, dll',
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Tanggal BAST'),
                              InkWell(
                                onTap: () => _pilihTanggal(context,
                                    ctrl.tanggalBast, ctrl.setTanggalBast),
                                child: InputDecorator(
                                  decoration: _glassInputDecoration(
                                      'Pilih tanggal BAST',
                                      suffixIcon: Icons.calendar_month),
                                  child: Text(
                                    ctrl.tanggalBast != null
                                        ? DateFormat('dd MMM yyyy')
                                            .format(ctrl.tanggalBast!)
                                        : 'Pilih tanggal BAST',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: ctrl.tanggalBast != null
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // =========================================================
                          // BAGIAN 6: CATATAN TAMBAHAN
                          // =========================================================
                          _buildGlassSection(
                            title: 'CATATAN TAMBAHAN',
                            icon: Icons.note_alt_outlined,
                            children: [
                              _buildLabel('Kekurangan Berkas'),
                              _buildGlassField(
                                controller: ctrl.kekuranganCtrl,
                                hint: 'Contoh: CLEAR, Kurang KTP, dll',
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('Per Kasus (Notes)'),
                              _buildGlassField(
                                controller: ctrl.notesCtrl,
                                hint: 'Catatan tambahan terkait kasus debitur',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('PIC Internal (Akad)'),
                              _buildGlassField(
                                controller: ctrl.picInternalCtrl,
                                hint: 'Nama staf yang memegang berkas',
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // =========================================================
                          // TOMBOL SIMPAN
                          // =========================================================
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.goldColor,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _simpan(context),
                              icon: const Icon(Icons.save_outlined,
                                  color: Colors.black),
                              label: const Text(
                                'SIMPAN DATA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET HELPERS - GLASSMORPHISM
  // ==========================================================================

  Widget _buildGlassSection(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppConstants.goldColor, size: 20),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    IconData? suffixIcon,
    String? prefixText,
    FocusNode? focusNode,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      // Fitur yang Anda minta: Mematikan auto huruf besar agar leluasa mengetik manual
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _glassInputDecoration(hint,
          suffixIcon: suffixIcon, prefixText: prefixText),
    );
  }

  InputDecoration _glassInputDecoration(String hint,
      {IconData? suffixIcon, String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: Colors.white, fontSize: 14),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: Colors.white.withOpacity(0.4), size: 20)
          : null,
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppConstants.goldColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
