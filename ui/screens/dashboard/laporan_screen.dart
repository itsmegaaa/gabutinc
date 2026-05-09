import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/laporan_model.dart';
import '../../../controllers/laporan_controller.dart';
import '../../../controllers/user_provider.dart';
import '../../../controllers/form_laporan_controller.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('LAPORAN ${laporanCtrl.tahunAktif}'),
        actions: [
          if (userProv.isAdmin)
            IconButton(
              icon: const Icon(Icons.sync, color: AppConstants.navyColor),
              tooltip: 'Sync Manual ke Sheet',
              onPressed: () =>
                  _konfirmasiSyncManual(context, laporanCtrl, userProv.email),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: CustomExpandableFab(
        onAddTap: () {
          // TAMBAHKAN BARIS INI: Cuci otak form agar benar-benar kosong (Mode Tambah Baru)
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
      body: Column(
        children: [
          // ==================================================================
          // SEARCH BAR
          // ==================================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) =>
                  context.read<LaporanController>().cariLaporan(value),
              decoration: InputDecoration(
                hintText: 'Cari debitur, bank, covernote...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<LaporanController>().cariLaporan('');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    isDark ? AppConstants.darkSurface : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.fieldBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ==================================================================
          // FILTER CHIPS
          // ==================================================================
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFilterChip('SEMUA', laporanCtrl, isDark),
                ...['PROSES', 'SELESAI', 'BATAL', 'PENDING'].map(
                  (status) => _buildFilterChip(status, laporanCtrl, isDark),
                ),
              ],
            ),
          ),

          // ==================================================================
          // LIST DATA
          // ==================================================================
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
                          return _buildListCard(
                              context, item, userProv, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGET HELPERS
  // ==========================================================================

  Widget _buildFilterChip(String label, LaporanController ctrl, bool isDark) {
    final isSelected = ctrl.statusFilter == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? AppConstants.goldColor
                : (isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ),
        selected: isSelected,
        selectedColor: AppConstants.navyColor,
        backgroundColor: isDark ? AppConstants.darkSurface : Colors.white,
        side: BorderSide(
          color: isSelected ? AppConstants.navyColor : Colors.grey.shade300,
        ),
        onSelected: (selected) {
          if (selected) {
            context.read<LaporanController>().ubahFilterStatus(label);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data ditemukan.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(BuildContext context, LaporanModel item,
      UserProvider userProv, bool isDark) {
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
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
        ),
        child: InkWell(
          onTap: () {
            context.read<FormLaporanController>().initForm(
                  laporanExisting: item,
                  tahunAktif: item.tahun,
                );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FormLaporanScreen()),
            );
          },
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark ? AppConstants.darkSurface : AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              boxShadow: [AppConstants.primaryShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Nama Debitur & Status/Sync Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.namaDebitur,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (!item.sudahSyncSheet) ...[
                      Tooltip(
                        message: 'Belum tersinkronisasi ke Sheet',
                        child: Icon(Icons.sync_problem,
                            size: 18, color: Colors.orange.shade700),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildStatusBadge(item.statusPekerjaan),
                  ],
                ),
                const SizedBox(height: 6),

                // Baris 2: Bank & Notaris
                Text(
                  '${item.namaBank} • ${item.namaNotaris}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),

                // Baris 3: Tgl Pelaksanaan & Batas SLA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatTanggalTampil(item.tanggalPelaksanaan),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    _buildSlaIndicator(item.tanggalPelaksanaan, item.batasSla,
                        item.statusPekerjaan),
                  ],
                ),
              ],
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
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'PROSES':
      case 'PROSES TANDATANGAN':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'BATAL':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'PENDING':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      bgColor = bgColor.withOpacity(0.1);
      textColor = textColor.withOpacity(0.9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  // REVISI LOGIKA SLA: Menghitung jarak dari hari ini ke "Batas SLA Laporan" (Format Tanggal)
  Widget _buildSlaIndicator(
      String tanggalPelaksanaanStr, String batasSlaStr, String status) {
    if (tanggalPelaksanaanStr.isEmpty ||
        batasSlaStr.isEmpty ||
        status == 'SELESAI' ||
        status == 'BATAL') {
      return const SizedBox.shrink();
    }

    try {
      final tglBatasSla = DateTime.parse(batasSlaStr);
      final sisaWaktu = tglBatasSla.difference(DateTime.now()).inDays;

      Color warnaSla = AppConstants.navyColor;
      String pesanSla = 'Sisa $sisaWaktu hari';

      if (sisaWaktu < 0) {
        warnaSla = Colors.red;
        pesanSla = 'Overdue ${sisaWaktu.abs()} hari';
      } else if (sisaWaktu <= 3) {
        warnaSla = Colors.orange.shade700;
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
      // Fallback jika batasSlaStr ternyata tidak bisa di-parse sebagai tanggal
      // (misal diisi teks manual oleh user)
      return Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 14, color: AppConstants.navyColor),
          const SizedBox(width: 4),
          Text(
            'SLA: $batasSlaStr',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppConstants.navyColor),
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

  // ==========================================================================
  // DIALOGS
  // ==========================================================================

  Future<bool?> _konfirmasiHapus(BuildContext context, String nama) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text(
            'Apakah Anda yakin ingin menghapus data debitur $nama secara permanen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _konfirmasiSyncManual(
      BuildContext context, LaporanController ctrl, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sinkronisasi Manual'),
        content: Text(
            'Tarik pembaruan data tahun ${ctrl.tahunAktif} ke Google Sheet sekarang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.navyColor,
              foregroundColor: AppConstants.goldColor,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.triggerSyncManual(email).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Permintaan sync berhasil dikirim.'),
                      backgroundColor: Colors.green),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Gagal: $e'), backgroundColor: Colors.red),
                );
              });
            },
            child: const Text('Sinkronkan'),
          ),
        ],
      ),
    );
  }
}
