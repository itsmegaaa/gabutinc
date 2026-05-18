import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/laporan_repository.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = context.read<LaporanRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RIWAYAT AKTIVITAS'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: repo.streamLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppConstants.goldColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi kesalahan saat memuat log',
                style: TextStyle(color: Colors.red.shade400),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat aktivitas.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final doc = logs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildLogCard(context, data, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildLogCard(
      BuildContext context, Map<String, dynamic> data, bool isDark) {
    final aksi = data['aksi'] as String? ?? 'UNKNOWN';
    final detail = data['detail'] as String? ?? '-';
    final oleh = data['oleh'] as String? ?? 'Sistem';
    final waktu = data['waktu'] as Timestamp?;

    // Konfigurasi Visual Berdasarkan Aksi
    Color actionColor;
    IconData actionIcon;

    switch (aksi.toUpperCase()) {
      case 'TAMBAH':
        actionColor = Colors.green;
        actionIcon = Icons.add_circle_outline;
        break;
      case 'EDIT':
        actionColor = Colors.blue;
        actionIcon = Icons.edit_note;
        break;
      case 'HAPUS':
        actionColor = Colors.red;
        actionIcon = Icons.delete_forever;
        break;
      case 'SYNC':
        actionColor = Colors.teal;
        actionIcon = Icons.sync;
        break;
      default:
        actionColor = Colors.grey;
        actionIcon = Icons.info_outline;
    }

    String waktuStr = '';
    if (waktu != null) {
      final date = waktu.toDate();
      waktuStr = DateFormat('dd MMM yyyy • HH:mm').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppConstants.primaryShadow],
        border: Border(
          left: BorderSide(color: actionColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Aksi
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(actionIcon, color: actionColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Detail Aksi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          aksi.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: actionColor,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          waktuStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8, left: 48),
            child: Divider(height: 1),
          ),

          // User Info
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  oleh,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
