import 'dart:ui'; // Wajib untuk ImageFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/globals.dart';
import '../../../controllers/user_provider.dart';
import '../../../controllers/laporan_controller.dart';
import '../../../data/repositories/laporan_repository.dart';

import '../dashboard/laporan_screen.dart';
import '../../../controllers/form_laporan_controller.dart';
import '../../widgets/custom_drawer.dart';
import '../form/form_laporan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final laporanCtrl = context.watch<LaporanController>();

    return Scaffold(
      extendBodyBehindAppBar: true, // Agar background menyatu ke status bar
      drawer: const CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // 1. Tambahkan iconTheme agar tombol menu (garis tiga) di kiri jadi putih
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'SIRA',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.white, // 2. Tambahkan warna putih pada teks judul
          ),
        ),
        actions: [
          Builder(
              builder: (ctx) => IconButton(
                    // 3. Tambahkan warna putih pada ikon profil di kanan
                    icon: const Icon(Icons.account_circle_outlined,
                        size: 28, color: Colors.white),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  )),
        ],
      ),
      body: Stack(
        children: [
          // 1. LATAR BELAKANG GRADASI DYNAMIS
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Navy SIRA
                  Color(0xFF1E293B),
                  Color(0xFF020617), // Deep Black
                ],
              ),
            ),
          ),

          // 2. ORNAMEN CAHAYA (Semburat untuk efek glass lebih nyata)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppConstants.goldColor.withOpacity(0.08),
              ),
            ),
          ),

          // 3. KONTEN UTAMA
          SafeArea(
            child: RefreshIndicator(
              color: AppConstants.goldColor,
              onRefresh: () async => laporanCtrl.mulaiListen(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${getSapaanWaktu()},',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 16),
                    ),
                    Text(
                      userProv.nama.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // BANNER SYNC GLASS
                    _buildGlassSyncBanner(context),
                    const SizedBox(height: 35),

                    const Text(
                      'Monitoring Berkas',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),

                    // BENTO GRID GLASS
                    _buildGlassBentoStats(laporanCtrl),
                    const SizedBox(height: 35),

                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    _buildGlassActions(context, laporanCtrl),

                    const SizedBox(height: 35),
                    const Text(
                      'Arsip Tahunan',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    ...AppConstants.listTahunAktif.reversed
                        .map((t) => _buildYearGlassCard(context, t)),
                    const SizedBox(height: 50),
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
  // COMPONENT: THE GLASS CARD (MODULAR)
  // ==========================================================================
  Widget _buildGlassCard(
      {required Widget child, double? height, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassBentoStats(LaporanController ctrl) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildGlassCard(
                height: 140,
                child: _statItem('TOTAL BERKAS', ctrl.totalBerkas.toString(),
                    Icons.folder, AppConstants.goldColor),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: _buildGlassCard(
                height: 140,
                child: _statItem('PROSES', ctrl.totalBulanIni.toString(),
                    Icons.bolt, Colors.blueAccent),
              ),
            ),
          ],
        ),
        const SizedBox(width: 15, height: 15),
        Row(
          children: [
            Expanded(
              child: _buildGlassCard(
                height: 120,
                child: _statItem('PENDING', ctrl.totalProses.toString(),
                    Icons.timer_sharp, Colors.orangeAccent),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGlassCard(
                height: 120,
                borderColor: Colors.redAccent.withOpacity(0.3),
                child: _statItem('BERMASALAH', ctrl.totalBermasalah.toString(),
                    Icons.gpp_maybe, Colors.redAccent),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassActions(BuildContext context, LaporanController ctrl) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              await context
                  .read<FormLaporanController>()
                  .initForm(laporanExisting: null, tahunAktif: ctrl.tahunAktif);
              if (context.mounted)
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FormLaporanScreen()));
            },
            child: _buildGlassCard(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: const [
                    Icon(Icons.add_to_photos_rounded,
                        color: Colors.greenAccent, size: 30),
                    SizedBox(height: 8),
                    Text('INPUT BARU',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: () =>
                _handleManualSync(context, context.read<UserProvider>().email),
            child: _buildGlassCard(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: const [
                    Icon(Icons.cloud_sync_rounded,
                        color: AppConstants.goldColor, size: 30),
                    SizedBox(height: 8),
                    Text('SYNC SHEET',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearGlassCard(BuildContext context, String tahun) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          context.read<LaporanController>().ubahTahun(tahun);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LaporanScreen()));
        },
        child: _buildGlassCard(
          child: ListTile(
            leading: const Icon(Icons.folder_shared_outlined,
                color: AppConstants.goldColor),
            title: Text('Data Tahun $tahun',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Ketuk untuk membuka arsip',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSyncBanner(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: context.read<LaporanRepository>().streamSyncStatus(),
      builder: (context, snapshot) {
        String msg = "Menghubungkan...";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['isSyncing'] == true) {
            msg = "Sedang sinkronisasi ke Google Sheets...";
          } else {
            final last = data['lastSyncToSheet'] as Timestamp?;
            msg = last != null
                ? "Terakhir Sync: ${DateFormat('HH:mm - dd/MM').format(last.toDate())}"
                : "Belum pernah sync";
          }
        }
        return _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: Colors.blueAccent, size: 20),
                const SizedBox(width: 12),
                Text(msg,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Logic Manual Sync (Gunakan Dialog Glass jika ingin lebih konsisten)
  void _handleManualSync(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.9),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10)),
          title:
              const Text('Sinkronisasi', style: TextStyle(color: Colors.white)),
          content: const Text('Kirim data terbaru ke Spreadsheet sekarang?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.goldColor),
              onPressed: () {
                Navigator.pop(ctx);
                context.read<LaporanController>().triggerSyncManual(email);
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
