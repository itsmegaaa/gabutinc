import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../controllers/user_provider.dart';
import '../../controllers/laporan_controller.dart';
import '../../data/repositories/laporan_repository.dart';
import '../../controllers/theme_controller.dart'; // Untuk ThemeController
import '../screens/master/master_bank_screen.dart'; // Sesuaikan path-nya jika berbeda

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final themeCtrl = context.watch<ThemeController>();
    final repo = context.read<LaporanRepository>();
    final isDark = themeCtrl.isDarkMode;

    return Drawer(
      backgroundColor: isDark ? AppConstants.darkBg : AppConstants.bgColor,
      child: Column(
        children: [
          // ==================================================================
          // HEADER DRAWER
          // ==================================================================
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppConstants.navyColor,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppConstants.goldColor.withOpacity(0.2),
              child: const Icon(Icons.person,
                  size: 40, color: AppConstants.goldColor),
            ),
            accountName: Text(
              userProv.nama,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Row(
              children: [
                Text(userProv.email),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: userProv.isAdmin
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    userProv.role,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ==================================================================
          // MENU PENGATURAN
          // ==================================================================
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Text(
                    'PENGATURAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // 1. Toggle Dark Mode
                SwitchListTile(
                  title: const Text('Mode Gelap'),
                  secondary: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark
                        ? AppConstants.goldColor
                        : AppConstants.navyColor,
                  ),
                  value: themeCtrl.isDarkMode,
                  activeColor: AppConstants.goldColor,
                  onChanged: (val) {
                    themeCtrl.toggleTheme();
                  },
                ),

                // 2. Pengaturan Default SLA
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.grey),
                  title: const Text('Service Level Agreement'),
                  subtitle: const Text('Pengaturan Deadline'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _tampilkanDialogSla(context),
                ),

                // 3. Kelola Master Notaris (Hanya ADMIN)
                if (userProv.isAdmin)
                  ListTile(
                    leading: const Icon(Icons.gavel, color: Colors.grey),
                    title: const Text('Daftar Nama Notaris'),
                    subtitle: const Text('Kelola daftar nama notaris'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _tampilkanKelolaNotaris(context),
                  ),

                // Menu Master Bank
                if (userProv.isAdmin)
                  ListTile(
                    leading:
                        const Icon(Icons.account_balance, color: Colors.grey),
                    title: const Text('Master Bank & PIC'),
                    subtitle: const Text('Kelola daftar nama PIC Bank'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Tutup drawer terlebih dahulu
                      Navigator.pop(context);
                      // Pindah ke halaman Master Bank
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MasterBankScreen(),
                        ),
                      );
                    },
                  ),

                // 4. Status Sync (Hanya ADMIN)
                if (userProv.isAdmin) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'SISTEM & SINKRONISASI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: repo.streamSyncStatus(),
                    builder: (context, snapshot) {
                      String sub = 'Memuat status...';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final isSyncing = data['isSyncing'] as bool? ?? false;
                        if (isSyncing) {
                          sub = 'Sedang menyinkronkan...';
                        } else {
                          final lastSync =
                              data['lastSyncToSheet'] as Timestamp?;
                          if (lastSync != null) {
                            sub =
                                'Terakhir: ${DateFormat('dd MMM HH:mm').format(lastSync.toDate())}';
                          } else {
                            sub = 'Belum ada sinkronisasi';
                          }
                        }
                      }
                      return ListTile(
                        leading: const Icon(Icons.sync, color: Colors.grey),
                        title: const Text('Sync ke Spreadsheet'),
                        subtitle: Text(sub),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.navyColor,
                            foregroundColor: AppConstants.goldColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Tutup drawer
                            _konfirmasiSyncManual(context, userProv.email);
                          },
                          child: const Text('SYNC',
                              style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ],

                const Divider(),

                // 5. Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Keluar Akun',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Keluar'),
                        content: const Text(
                            'Apakah Anda yakin ingin keluar dari aplikasi?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () {
                              Navigator.pop(ctx);
                              userProv.logout();
                            },
                            child: const Text('Keluar',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ==================================================================
          // FOOTER (VERSI)
          // ==================================================================
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'SIRA v1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DIALOG: PENGATURAN SLA
  // ==========================================================================

  Future<void> _tampilkanDialogSla(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int currentSla = prefs.getInt(AppConstants.keyDefaultSla) ?? 30;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        int selectedSla = currentSla;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Target SLA Default'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Pilih default hari SLA untuk form tambah data baru:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedSla,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    items: [14, 21, 30, 45, 60].map((val) {
                      return DropdownMenuItem(
                          value: val, child: Text('$val Hari'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedSla = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.navyColor),
                  onPressed: () async {
                    await prefs.setInt(AppConstants.keyDefaultSla, selectedSla);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(
                                'SLA Default diubah menjadi $selectedSla hari')),
                      );
                    }
                  },
                  child: const Text('Simpan',
                      style: TextStyle(color: AppConstants.goldColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // DIALOG: MASTER DATA NOTARIS
  // ==========================================================================

  void _tampilkanKelolaNotaris(BuildContext context) {
    final repo = context.read<LaporanRepository>();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              children: [
                const Text('Master Data Notaris',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: repo.streamMasterNotaris(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<String> notarisList = [];
                      if (snapshot.data!.exists &&
                          snapshot.data!.data() != null) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        if (data.containsKey('items')) {
                          notarisList = List<String>.from(data['items']);
                        }
                      }

                      if (notarisList.isEmpty) {
                        return const Center(
                            child: Text('Belum ada data notaris.'));
                      }

                      return ListView.builder(
                        itemCount: notarisList.length,
                        itemBuilder: (context, index) {
                          final nama = notarisList[index];
                          return ListTile(
                            title: Text(nama),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => repo.hapusNotaris(nama),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.navyColor,
                    foregroundColor: AppConstants.goldColor,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Notaris'),
                  onPressed: () => _tambahNotarisBaru(ctx, repo),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _tambahNotarisBaru(BuildContext context, LaporanRepository repo) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Notaris Baru'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Masukkan nama notaris'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final namaBaru = ctrl.text.trim();
              if (namaBaru.isNotEmpty) {
                await repo.tambahNotaris(namaBaru);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AKSI: SYNC MANUAL
  // ==========================================================================

  void _konfirmasiSyncManual(BuildContext context, String email) {
    final ctrl = context.read<LaporanController>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sinkronisasi Manual'),
        content: const Text(
            'Tindakan ini akan memakan waktu beberapa saat untuk menarik data dari Firebase ke Spreadsheet. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.navyColor),
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.triggerSyncManual(email).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Proses sinkronisasi dimulai...'),
                      backgroundColor: Colors.green),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Gagal: $e'), backgroundColor: Colors.red),
                );
              });
            },
            child: const Text('Ya, Sinkronkan',
                style: TextStyle(color: AppConstants.goldColor)),
          ),
        ],
      ),
    );
  }
}
