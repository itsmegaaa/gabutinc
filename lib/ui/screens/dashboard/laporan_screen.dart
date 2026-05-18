import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/laporan_model.dart';
import '../../../controllers/laporan_controller.dart';
import '../../../controllers/user_provider.dart';
import '../../../controllers/form_laporan_controller.dart';
import '../../screens/portal/detail_laporan_screen.dart';

import '../form/form_laporan_screen.dart';
import 'log_screen.dart';
import '../../widgets/expandable_fab.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({Key? key}) : super(key: key);

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final laporanCtrl = context.watch<LaporanController>();
    final userProv = context.watch<UserProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'LAPORAN ${laporanCtrl.tahunAktif}',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
        ),
        centerTitle: true,
        actions: [
          if (userProv.isAdmin)
            IconButton(
              icon: const Icon(Icons.sync, color: AppConstants.goldColor),
              tooltip: 'Sync Manual ke Sheet',
              onPressed: () =>
                  _konfirmasiSyncManual(context, laporanCtrl, userProv.email),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: CustomExpandableFab(
        onAddTap: () {
          context.read<FormLaporanController>().initForm(
                laporanExisting: null,
                tahunAktif: context.read<LaporanController>().tahunAktif,
              );

          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormLaporanScreen()),
          );
        },
        onLogTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LogScreen()),
          );
        },
      ),
      body: Stack(
        children: [
          // ==================================================================
          // BACKGROUND GRADIENT (Glassmorphism Base)
          // ==================================================================
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
              ),
            ),
          ),

          // ==================================================================
          // KONTEN UTAMA
          // ==================================================================
          SafeArea(
            child: Column(
              children: [
                // ============================================================
                // SEARCH BAR & FILTER MENU (TERINTEGRASI)
                // ============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: const TextStyle(color: Colors.white),
                                onChanged: (value) => context
                                    .read<LaporanController>()
                                    .cariLaporan(value),
                                decoration: InputDecoration(
                                  hintText: 'Cari debitur, bank, covernote...',
                                  hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 14),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Colors.white54),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),

                            // Tombol Silang untuk Hapus Teks Search
                            if (_searchCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white54, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  context
                                      .read<LaporanController>()
                                      .cariLaporan('');
                                  FocusScope.of(context).unfocus();
                                },
                              ),

                            // Garis Pemisah Transparan
                            Container(
                                height: 24,
                                width: 1,
                                color: Colors.white.withOpacity(0.2)),

                            // Menu Filter Pop-up (Menyatu dengan Search Bar)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.filter_list_rounded,
                                // Berubah jadi Emas kalau filter sedang aktif
                                color: laporanCtrl.statusFilter == 'SEMUA'
                                    ? Colors.white54
                                    : AppConstants.goldColor,
                              ),
                              color: const Color(
                                  0xFF1E293B), // Background pop-up menu
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              tooltip: 'Filter Status Pekerjaan',
                              onSelected: (String status) {
                                context
                                    .read<LaporanController>()
                                    .ubahFilterStatus(status);
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  'SEMUA',
                                  'PROSES',
                                  'SELESAI',
                                  'BATAL',
                                  'PENDING',
                                  'BERMASALAH'
                                ].map((String choice) {
                                  final isSelected =
                                      laporanCtrl.statusFilter == choice;
                                  return PopupMenuItem<String>(
                                    value: choice,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: isSelected
                                              ? AppConstants.goldColor
                                              : Colors.white54,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          choice,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppConstants.goldColor
                                                : Colors.white,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            const SizedBox(width: 5), // Padding tipis
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // SUMMARY HEADER
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                  child: Row(
                    children: [
                      Text(
                        'Total: ${laporanCtrl.dataLaporan.length} Berkas',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      const Spacer(),
                      // Teks indikator kecil jika filter aktif
                      if (laporanCtrl.statusFilter != 'SEMUA')
                        Text(
                          'Filter: ${laporanCtrl.statusFilter}',
                          style: const TextStyle(
                              color: AppConstants.goldColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                    ],
                  ),
                ),

                // LIST DATA
                Expanded(
                  child: laporanCtrl.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppConstants.goldColor),
                        )
                      : laporanCtrl.dataLaporan.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(
                                  left: 20, right: 20, bottom: 100),
                              itemCount: laporanCtrl.dataLaporan.length,
                              itemBuilder: (context, index) {
                                final item = laporanCtrl.dataLaporan[index];
                                return _buildListCard(context, item, userProv);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET HELPERS
  // ==========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data ditemukan.',
            style:
                TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
      BuildContext context, LaporanModel item, UserProvider userProv) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(item.id),
        direction: userProv.isAdmin
            ? DismissDirection.endToStart
            : DismissDirection.none,
        confirmDismiss: (direction) =>
            _konfirmasiHapus(context, item.namaDebitur),
        onDismissed: (direction) {
          context
              .read<LaporanController>()
              .hapusData(item.id, item.namaDebitur, userProv.email);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.namaDebitur} berhasil dihapus')),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailLaporanScreen(item: item),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.namaDebitur.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (!item.sudahSyncSheet) ...[
                              const Tooltip(
                                message: 'Belum tersinkronisasi ke Sheet',
                                child: Icon(Icons.sync_problem,
                                    size: 18, color: Colors.orangeAccent),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildStatusBadge(item.statusPekerjaan),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.namaBank} • ${item.namaNotaris}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: Colors.white10, height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_month,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.5)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTanggalTampil(item.tanggalPelaksanaan),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6)),
                                ),
                              ],
                            ),
                            _buildSlaIndicator(item.tanggalPelaksanaan,
                                item.batasSla, item.statusPekerjaan),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'SELESAI':
        bgColor = Colors.greenAccent.withOpacity(0.2);
        textColor = Colors.greenAccent;
        break;
      case 'PROSES':
      case 'PROSES TANDATANGAN':
        bgColor = Colors.blueAccent.withOpacity(0.2);
        textColor = Colors.blueAccent;
        break;
      case 'BATAL':
        bgColor = Colors.redAccent.withOpacity(0.2);
        textColor = Colors.redAccent;
        break;
      case 'PENDING':
        bgColor = Colors.orangeAccent.withOpacity(0.2);
        textColor = Colors.orangeAccent;
        break;
      default:
        bgColor = Colors.white.withOpacity(0.1);
        textColor = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.5)),
      ),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildSlaIndicator(
      String tanggalPelaksanaanStr, String batasSlaStr, String status) {
    if (tanggalPelaksanaanStr.isEmpty ||
        batasSlaStr.isEmpty ||
        status == 'SELESAI' ||
        status == 'BATAL') {
      return const SizedBox.shrink();
    }

    DateTime? parseFlexibleDate(String dateStr) {
      if (dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (_) {}
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          return DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
      return null;
    }

    try {
      final tglBatasSla = parseFlexibleDate(batasSlaStr);
      if (tglBatasSla == null)
        throw const FormatException('Format tanggal tidak valid');

      final sisaWaktu = tglBatasSla.difference(DateTime.now()).inDays;

      Color warnaSla = AppConstants.goldColor;
      String pesanSla = 'Sisa $sisaWaktu hari';

      if (sisaWaktu < 0) {
        warnaSla = Colors.redAccent;
        pesanSla = 'Overdue ${sisaWaktu.abs()} hari';
      } else if (sisaWaktu <= 3) {
        warnaSla = Colors.orangeAccent;
      }

      return Row(
        children: [
          Icon(Icons.timer_outlined, size: 14, color: warnaSla),
          const SizedBox(width: 4),
          Text(
            pesanSla,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: warnaSla),
          ),
        ],
      );
    } catch (_) {
      return Row(
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            'SLA: $batasSlaStr',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
        ],
      );
    }
  }

  String _formatTanggalTampil(String isoDate) {
    if (isoDate.isEmpty) return 'Belum Pelaksanaan';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  Future<bool?> _konfirmasiHapus(BuildContext context, String nama) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10)),
          title:
              const Text('Hapus Data', style: TextStyle(color: Colors.white)),
          content: Text(
              'Apakah Anda yakin ingin menghapus data debitur $nama secara permanen?',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child:
                  const Text('Batal', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _konfirmasiSyncManual(
      BuildContext context, LaporanController ctrl, String email) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10)),
          title:
              const Text('Sinkronisasi', style: TextStyle(color: Colors.white)),
          content: Text(
              'Tarik pembaruan data tahun ${ctrl.tahunAktif} ke Google Sheet sekarang?',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Batal', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.goldColor),
              onPressed: () {
                Navigator.pop(ctx);
                ctrl.triggerSyncManual(email);
              },
              child: const Text('Ya, Sync',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
