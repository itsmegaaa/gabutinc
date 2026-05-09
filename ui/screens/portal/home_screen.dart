import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/globals.dart';
import '../../../controllers/user_provider.dart';
import '../../../controllers/laporan_controller.dart';
import '../../../data/repositories/laporan_repository.dart';

// Import layar & widget yang akan dibuat nanti
import '../dashboard/laporan_screen.dart';
import '../form/form_laporan_screen.dart';
import '../../widgets/custom_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final laporanCtrl = context.watch<LaporanController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Sistem Informasi Riwayat Administrasi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () {
              // Buka drawer menggunakan GlobalKey atau fungsi bawaan Scaffold
              Scaffold.of(context).openDrawer();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppConstants.goldColor,
        onRefresh: () async {
          laporanCtrl.mulaiListen();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SAPAAN DINAMIS
              Text(
                '${getSapaanWaktu()},',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userProv.nama.toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      AppConstants.navyColor, // Tetap gunakan navy atau adaptif
                ).copyWith(
                    color: isDark ? Colors.white : AppConstants.navyColor),
              ),
              const SizedBox(height: 24),

              // 2. BANNER STATUS SYNC
              _buildSyncBanner(context),
              const SizedBox(height: 24),

              // 3. KARTU STATISTIK
              _buildStatCard(context, laporanCtrl, isDark),
              const SizedBox(height: 24),

              // 4. PINTASAN AKSI CEPAT
              const Text(
                'Aksi Cepat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      icon: Icons.add_circle_outline,
                      label: 'Input Data\nBaru',
                      color: Colors.green.shade600,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FormLaporanScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      icon: Icons.sync,
                      label: 'Sync ke\nSheet',
                      color: AppConstants.navyColor,
                      onTap: () => _handleManualSync(context, userProv.email),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. MENU NAVIGASI PER TAHUN
              const Text(
                'Arsip Laporan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...AppConstants.listTahunAktif.reversed.map((tahun) {
                return _buildYearCard(context, tahun, isDark);
              }).toList(),
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

  Widget _buildSyncBanner(BuildContext context) {
    final repo = context.read<LaporanRepository>();

    return StreamBuilder<DocumentSnapshot>(
      stream: repo.streamSyncStatus(),
      builder: (context, snapshot) {
        String pesan = 'Memuat status sinkronisasi...';
        Color bgColor = Colors.blue.shade50;
        Color textColor = Colors.blue.shade800;
        IconData icon = Icons.info_outline;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final isSyncing = data['isSyncing'] as bool? ?? false;

          if (isSyncing) {
            pesan = '🔄 Sedang menyinkronkan data...';
            bgColor = Colors.orange.shade50;
            textColor = Colors.orange.shade900;
            icon = Icons.sync;
          } else {
            final lastSync = data['lastSyncToSheet'] as Timestamp?;
            if (lastSync != null) {
              final formattedTime =
                  DateFormat('dd MMM yyyy, HH:mm').format(lastSync.toDate());
              pesan = '✅ Sync terakhir: $formattedTime';
              bgColor = Colors.green.shade50;
              textColor = Colors.green.shade900;
              icon = Icons.check_circle_outline;
            } else {
              pesan = '⚠️ Belum ada riwayat sinkronisasi';
              bgColor = Colors.amber.shade50;
              textColor = Colors.amber.shade900;
              icon = Icons.warning_amber_rounded;
            }
          }
        }

        // Tweak warna untuk dark mode
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (isDark) {
          bgColor = bgColor.withOpacity(0.1);
          textColor = Colors.white70;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pesan,
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      BuildContext context, LaporanController ctrl, bool isDark) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Statistik Berkas ${ctrl.tahunAktif}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.analytics_outlined,
                  color: AppConstants.goldColor),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statItem(
                    'Bulan Ini', ctrl.totalBulanIni.toString(), Colors.blue),
              ),
              _divider(),
              Expanded(
                child: _statItem(
                    'Proses', ctrl.totalProses.toString(), Colors.orange),
              ),
              _divider(),
              Expanded(
                child: _statItem(
                    'Selesai', ctrl.totalSelesai.toString(), Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 40,
        width: 1,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkSurface : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: [AppConstants.primaryShadow],
          border: Border.all(
            color: color.withOpacity(isDark ? 0.3 : 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearCard(BuildContext context, String tahun, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Set tahun aktif di controller, lalu navigasi
          context.read<LaporanController>().ubahTahun(tahun);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LaporanScreen()),
          );
        },
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                isDark ? AppConstants.darkSurface : AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            boxShadow: [AppConstants.primaryShadow],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      AppConstants.navyColor.withOpacity(isDark ? 0.5 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_open,
                    color: AppConstants.goldColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buku Laporan $tahun',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ketuk untuk melihat daftar berkas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ACTION HANDLERS
  // ==========================================================================

  void _handleManualSync(BuildContext context, String userEmail) {
    final userProv = context.read<UserProvider>();
    if (!userProv.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Hanya ADMIN yang dapat melakukan sinkronisasi manual.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sinkronisasi Manual'),
        content: const Text(
            'Tindakan ini akan menarik data terbaru dari Firestore dan menulis ulang ke Spreadsheet. Lanjutkan?'),
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
              context
                  .read<LaporanController>()
                  .triggerSyncManual(userEmail)
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Permintaan sinkronisasi berhasil dikirim.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            },
            child: const Text('Ya, Sinkronkan'),
          ),
        ],
      ),
    );
  }
}
