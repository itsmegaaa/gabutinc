import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../controllers/form_laporan_controller.dart';
import '../form/form_laporan_screen.dart';

class DetailLaporanScreen extends StatelessWidget {
  final dynamic item; // Menerima data kartu yang ditekan

  const DetailLaporanScreen({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'DETAIL BERKAS',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // BACKGROUND DARK GRADIENT
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER PREVIEW (Nama Debitur & Status)
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: AppConstants.goldColor,
                          child: Icon(Icons.folder_shared,
                              size: 40, color: Colors.black),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.namaDebitur.toString().toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.5)),
                          ),
                          child: Text(
                            item.statusPekerjaan,
                            style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // KOTAK KACA: DATA LENGKAP
                  _buildGlassSection(
                    title: 'INFORMASI UMUM',
                    icon: Icons.person_outline,
                    children: [
                      _buildDetailRow('Nama Notaris', item.namaNotaris),
                      _buildDetailRow('KCU/KCP Bank', item.namaBank),
                      _buildDetailRow('PIC Bank', item.picBank),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildGlassSection(
                    title: 'DETAIL ORDER',
                    icon: Icons.assignment_outlined,
                    children: [
                      _buildDetailRow('No. Surat Order', item.noSuratOrder),
                      _buildDetailRow('Tanggal Order', item.tanggalOrder),
                      _buildDetailRow('Jenis', item.jenis),
                      _buildDetailRow('Rincian Order', item.rincianOrder),
                      _buildDetailRow('No. Covernote', item.noCovernote),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildGlassSection(
                    title: 'PELAKSANAAN & SLA',
                    icon: Icons.timer_outlined,
                    children: [
                      _buildDetailRow('Umur Pekerjaan', item.umurPekerjaan),
                      // Tambahkan field lain yang ingin Anda lihat di preview
                      _buildDetailRow('Progres Terakhir', item.progresDetail),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // TOMBOL MENUJU HALAMAN EDIT
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.goldColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit_document),
                      label: const Text(
                        'EDIT BERKAS INI',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1),
                      ),
                      onPressed: () async {
                        // Inisialisasi data form
                        await context.read<FormLaporanController>().initForm(
                              laporanExisting: item,
                              tahunAktif: item
                                  .tahun, // atau tahun yang sesuai dari item
                            );

                        // Pergi ke halaman FormLaporanScreen
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FormLaporanScreen()),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Pembuat Kotak Kaca
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
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper Pembuat Baris Teks Detail
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value.toString().isEmpty || value == 'null'
                ? '-'
                : value.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
