import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Mencegah error TextInputFormatter
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppConstants.navyColor,
              onPrimary: AppConstants.goldColor,
              onSurface: AppConstants.navyColor,
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
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FormLaporanController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(ctrl.isEditMode ? 'EDIT LAPORAN' : 'TAMBAH LAPORAN'),
        centerTitle: true,
      ),
      body: ctrl.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppConstants.goldColor))
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
                    _buildSectionCard(
                      title: 'INFORMASI UMUM',
                      icon: Icons.person_outline,
                      isDark: isDark,
                      children: [
                        _buildLabel('Nama Debitur (Wajib)'),
                        _buildTextField(
                          controller: ctrl.namaDebiturCtrl,
                          hint: 'Masukkan nama debitur',
                          isDark: isDark,
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Nama Notaris'),
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty)
                              return const Iterable<String>.empty();
                            return _listNotaris.where((option) => option
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (String selection) =>
                              ctrl.setNamaNotaris(selection),
                          fieldViewBuilder: (context, textEditingController,
                              focusNode, onFieldSubmitted) {
                            if (ctrl.namaNotarisCtrl.text.isNotEmpty &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  ctrl.namaNotarisCtrl.text;
                            }
                            textEditingController.addListener(() {
                              ctrl.namaNotarisCtrl.text =
                                  textEditingController.text;
                            });
                            return _buildTextField(
                              controller: textEditingController,
                              hint: 'Pilih atau ketik nama notaris',
                              isDark: isDark,
                              focusNode: focusNode,
                              onChanged: (val) {
                                ctrl.namaNotarisCtrl.text = val;
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('KCU/KCP (Bank)'),
                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<
                                  Map<String, dynamic>>.empty();
                            }
                            return ctrl.listMasterBank.where((option) {
                              final namaBank =
                                  option['namaBank'].toString().toLowerCase();
                              return namaBank.contains(
                                  textEditingValue.text.toLowerCase());
                            });
                          },
                          displayStringForOption: (option) =>
                              option['namaBank'] as String,
                          onSelected: (selection) => ctrl.setNamaBankDanPic(
                              selection['namaBank'] as String),
                          fieldViewBuilder: (context, textEditingController,
                              focusNode, onFieldSubmitted) {
                            // Sinkronisasi teks awal saat mode Edit
                            if (ctrl.namaBankCtrl.text.isNotEmpty &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  ctrl.namaBankCtrl.text;
                            }

                            return _buildTextField(
                              controller: textEditingController,
                              hint: 'Ketik nama KCU/KCP Bank...',
                              isDark: isDark,
                              focusNode: focusNode,
                              onChanged: (val) {
                                ctrl.namaBankCtrl.text = val;
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('PIC Bank'),
                        _buildTextField(
                          controller: ctrl.picBankCtrl,
                          hint: 'Nama PIC Bank terkait',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // =========================================================
                    // BAGIAN 2: DETAIL ORDER
                    // =========================================================
                    _buildSectionCard(
                      title: 'DETAIL ORDER',
                      icon: Icons.assignment_outlined,
                      isDark: isDark,
                      children: [
                        _buildLabel('No. Surat Order'),
                        _buildTextField(
                          controller: ctrl.noSuratOrderCtrl,
                          hint: 'Contoh: R06.UM.GKD/0004/2026',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Tanggal Order'),
                        InkWell(
                          onTap: () => _pilihTanggal(
                              context, ctrl.tanggalOrder, ctrl.setTanggalOrder),
                          child: InputDecorator(
                            decoration:
                                _inputDecoration('Pilih tanggal order', isDark)
                                    .copyWith(
                              suffixIcon: const Icon(Icons.calendar_month,
                                  color: Colors.grey),
                            ),
                            child: Text(
                              ctrl.tanggalOrder != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(ctrl.tanggalOrder!)
                                  : 'Pilih tanggal order',
                              style: TextStyle(
                                fontSize: 14,
                                color: ctrl.tanggalOrder != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Jenis'),
                        DropdownButtonFormField<String>(
                          // Logika aman: Jika isi teks bukan dari 2 pilihan ini, jadikan null (kosong) agar tidak crash
                          value: ['Hak Tanggungan', 'Lainnya', 'Fidusia']
                                  .contains(ctrl.jenisCtrl.text)
                              ? ctrl.jenisCtrl.text
                              : null,
                          hint: Text('Pilih jenis order',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14)),
                          isExpanded: true,
                          decoration: _inputDecoration('', isDark),
                          dropdownColor:
                              isDark ? AppConstants.darkSurface : Colors.white,
                          items: ['Hak Tanggungan', 'Lainnya', 'Fidusia']
                              .map((String val) {
                            return DropdownMenuItem(
                              value: val,
                              child: Text(val,
                                  style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ctrl.jenisCtrl.text =
                                  val; // Simpan pilihan ke dalam controller
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Rincian Order'),
                        _buildTextField(
                          controller: ctrl.rincianOrderCtrl,
                          hint: 'Contoh: SHM No. 00037/Desa Mekarbakti...',
                          isDark: isDark,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('No. Covernote'),
                        _buildTextField(
                          controller: ctrl.noCovernoteCtrl,
                          hint: 'Masukkan no covernote',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // =========================================================
                    // BAGIAN 3: FINANSIAL
                    // =========================================================
                    _buildSectionCard(
                      title: 'FINANSIAL',
                      icon: Icons.monetization_on_outlined,
                      isDark: isDark,
                      children: [
                        _buildLabel('Limit / Plafon'),
                        _buildTextField(
                          controller: ctrl.limitPlafonCtrl,
                          hint: '0',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyFormatIdr()],
                          prefixText: 'Rp ',
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Nilai HT'),
                        _buildTextField(
                          controller: ctrl.nilaiHTCtrl,
                          hint: '0',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyFormatIdr()],
                          prefixText: 'Rp ',
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Biaya Notaris'),
                        _buildTextField(
                          controller: ctrl.biayaNotarisCtrl,
                          hint: '0',
                          isDark: isDark,
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
                    _buildSectionCard(
                      title: 'PELAKSANAAN & SLA',
                      icon: Icons.timer_outlined,
                      isDark: isDark,
                      children: [
                        _buildLabel('Tanggal Pelaksanaan'),
                        InputDecorator(
                          decoration: _inputDecoration(
                                  'Otomatis mengikuti Tanggal Order', isDark)
                              .copyWith(
                            suffixIcon: const Icon(Icons.lock_outline,
                                color: Colors.grey),
                          ),
                          child: Text(
                            ctrl.tanggalPelaksanaan != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(ctrl.tanggalPelaksanaan!)
                                : 'Otomatis mengikuti Tanggal Order',
                            style: TextStyle(
                              fontSize: 14,
                              color: ctrl.tanggalPelaksanaan != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Batas SLA Laporan'),
                        IgnorePointer(
                          child: _buildTextField(
                            controller: ctrl.batasSlaCtrl,
                            hint: 'Dihitung otomatis (Tgl Pelaksanaan + SLA)',
                            isDark: isDark,
                            suffixIcon: Icons.lock_outline, // Ikon gembok
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Umur Pekerjaan'),
                        IgnorePointer(
                          child: _buildTextField(
                            controller: ctrl.umurPekerjaanCtrl,
                            hint: 'Dihitung otomatis (Hari Ini - Tgl Order)',
                            isDark: isDark,
                            suffixIcon: Icons.lock_outline, // Ikon gembok
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // =========================================================
                    // BAGIAN 5: PROGRES & BAST
                    // =========================================================
                    _buildSectionCard(
                      title: 'PROGRES & BAST',
                      icon: Icons.trending_up_rounded,
                      isDark: isDark,
                      children: [
                        _buildLabel('Progres Pekerjaan (Status)'),
                        DropdownButtonFormField<String>(
                          value: AppConstants.listStatusPekerjaan
                                  .contains(ctrl.statusPekerjaan)
                              ? ctrl.statusPekerjaan
                              : null,
                          hint: Text('Pilih Status',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14)),
                          isExpanded: true,
                          decoration: _inputDecoration('', isDark),
                          dropdownColor:
                              isDark ? AppConstants.darkSurface : Colors.white,
                          items: AppConstants.listStatusPekerjaan
                              .map((String val) {
                            return DropdownMenuItem(
                                value: val,
                                child: Text(val,
                                    style: const TextStyle(fontSize: 14)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) ctrl.setStatusPekerjaan(val);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Progres Terakhir / Keterangan'),
                        _buildTextField(
                          controller: ctrl.progresDetailCtrl,
                          hint: 'Contoh: SKMHT, Selesai Cetak, dll',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Tanggal BAST'),
                        InkWell(
                          onTap: () => _pilihTanggal(
                              context, ctrl.tanggalBast, ctrl.setTanggalBast),
                          child: InputDecorator(
                            decoration:
                                _inputDecoration('Pilih tanggal BAST', isDark)
                                    .copyWith(
                              suffixIcon: const Icon(Icons.calendar_month,
                                  color: Colors.grey),
                            ),
                            child: Text(
                              ctrl.tanggalBast != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(ctrl.tanggalBast!)
                                  : 'Pilih tanggal BAST',
                              style: TextStyle(
                                fontSize: 14,
                                color: ctrl.tanggalBast != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey.shade400,
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
                    _buildSectionCard(
                      title: 'CATATAN TAMBAHAN',
                      icon: Icons.note_alt_outlined,
                      isDark: isDark,
                      children: [
                        _buildLabel('Kekurangan Berkas'),
                        _buildTextField(
                          controller: ctrl.kekuranganCtrl,
                          hint: 'Contoh: CLEAR, Kurang KTP, dll',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Per Kasus (Notes)'),
                        _buildTextField(
                          controller: ctrl.notesCtrl,
                          hint: 'Catatan tambahan terkait kasus debitur',
                          isDark: isDark,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('PIC Internal (Akad)'),
                        _buildTextField(
                          controller: ctrl.picInternalCtrl,
                          hint: 'Nama staf yang memegang berkas',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // =========================================================
                    // TOMBOL SIMPAN
                    // =========================================================
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.navyColor,
                          foregroundColor: AppConstants.goldColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () => _simpan(context),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'SIMPAN DATA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================================================
  // WIDGET HELPERS
  // ==========================================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [AppConstants.primaryShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConstants.goldColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
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
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(hint, isDark).copyWith(
        prefixText: prefixText,
        suffixIcon:
            suffixIcon != null ? Icon(suffixIcon, color: Colors.grey) : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.fieldBorderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.fieldBorderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.fieldBorderRadius),
        borderSide: const BorderSide(color: AppConstants.navyColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.fieldBorderRadius),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.fieldBorderRadius),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
