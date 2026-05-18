import 'package:flutter/material.dart';

class AppConstants {
  // ============================================================================
  // PALET WARNA (Wajib Sesuai Spesifikasi)
  // ============================================================================
  static const Color navyColor = Color(0xFF0F172A);
  static const Color goldColor = Color(0xFFD4AF37);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;

  // Dark Mode
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);

  // ============================================================================
  // DROPDOWN VALUES
  // ============================================================================
  static const List<String> listStatusPekerjaan = [
    'PROSES',
    'BATAL',
    'PENDING',
    'BERMASALAH',
    'SELESAI',
  ];

  static const List<String> listTahunAktif = [
    '2023',
    '2024',
    '2025',
    '2026',
  ];

  // ============================================================================
  // STYLE CONSTANTS
  // ============================================================================
  static const double borderRadius = 20.0;
  static const double fieldBorderRadius = 16.0;

  // FIX MEDIUM: Tambahkan 'final' agar shadow hanya dihitung satu kali
  static final BoxShadow primaryShadow = BoxShadow(
    color: Colors.black.withOpacity(0.03),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );

  // ============================================================================
  // KEY SHARED PREFERENCES
  // ============================================================================
  static const String keyTemaGelap = 'tema_gelap';
  static const String keyDefaultSla = 'default_sla';
}
