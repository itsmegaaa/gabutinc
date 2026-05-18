import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../controllers/user_provider.dart';
import '../../controllers/laporan_controller.dart';
import '../../data/repositories/laporan_repository.dart';
import '../screens/master/master_bank_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // EFFECT GLASSMORPHISM
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                border: Border(
                  right: BorderSide(
                      color: Colors.white.withOpacity(0.1), width: 1.5),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // HEADER DRAWER
                Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: AppConstants.goldColor,
                        child:
                            Icon(Icons.person, size: 50, color: Colors.black),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        userProv.nama,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      Text(
                        userProv.isAdmin ? 'ADMINISTRATOR' : 'STAFF',
                        style: TextStyle(
                            color: AppConstants.goldColor.withOpacity(0.7),
                            fontSize: 10,
                            letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, indent: 20, endIndent: 20),

                // DAFTAR MENU
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      _buildDrawerItem(
                        icon: Icons.dashboard_outlined,
                        title: 'DASHBOARD',
                        onTap: () => Navigator.pop(context),
                      ),

                      _buildDrawerItem(
                        icon: Icons.account_balance_outlined,
                        title: 'NAMA BANK & PIC',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MasterBankScreen()));
                        },
                      ),

                      // 3. Kelola Master Notaris (Hanya ADMIN)
                      if (userProv.isAdmin)
                        _buildDrawerItem(
                          icon: Icons.gavel_rounded,
                          title: 'DAFTAR NAMA NOTARIS',
                          onTap: () {
                            Navigator.pop(context); // Tutup drawer dulu
                            _tampilkanKelolaNotaris(context);
                          },
                        ),

                      if (userProv.isAdmin)
                        _buildDrawerItem(
                          icon: Icons.sync_rounded,
                          title: 'SYNC KE GOOGLE SHEET',
                          color: AppConstants.goldColor,
                          onTap: () {
                            Navigator.pop(context);
                            _konfirmasiSyncManual(context, userProv.email);
                          },
                        ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'KELUAR APLIKASI',
                  color: Colors.redAccent,
                  onTap: () => userProv.logout(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
      leading: Icon(icon, color: color.withOpacity(0.7)),
      title: Text(
        title,
        style: TextStyle(
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1),
      ),
    );
  }

  // ==========================================================================
  // LOGIKA KELOLA NOTARIS (FIXED)
  // ==========================================================================
  void _tampilkanKelolaNotaris(BuildContext context) {
    final repo = context.read<LaporanRepository>();
    final TextEditingController _notarisBaruCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10)),
          title: const Text('Kelola Daftar Notaris',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input Notaris Baru
                TextField(
                  controller: _notarisBaruCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tambah nama notaris...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: AppConstants.goldColor),
                      onPressed: () async {
                        if (_notarisBaruCtrl.text.trim().isNotEmpty) {
                          await repo
                              .tambahNotaris(_notarisBaruCtrl.text.trim());
                          _notarisBaruCtrl.clear();
                          (ctx as Element).markNeedsBuild(); // Refresh dialog
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // List Notaris yang ada
                Flexible(
                  child: FutureBuilder<List<String>>(
                    future: repo.getMasterNotaris(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const CircularProgressIndicator();
                      final list = snapshot.data!;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            title: Text(list[index],
                                style: const TextStyle(color: Colors.white70)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_sweep,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                await repo.hapusNotaris(list[index]);
                                (ctx as Element)
                                    .markNeedsBuild(); // Refresh dialog
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup',
                    style: TextStyle(color: Colors.white38))),
          ],
        ),
      ),
    );
  }

  void _konfirmasiSyncManual(BuildContext context, String email) {
    final ctrl = context.read<LaporanController>();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
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
