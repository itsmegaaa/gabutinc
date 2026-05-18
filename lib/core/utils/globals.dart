import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ============================================================================
// FORMATTER RUPIAH STRINGS (Sesuai Konvensi Kode Wajib)
// ============================================================================
final _rupiahFormat = NumberFormat.currency(
  locale: 'id',
  symbol: '',
  decimalDigits: 0,
);

String formatRupiah(String angka) {
  String clean = angka.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.isEmpty) return '0';
  return _rupiahFormat.format(int.parse(clean));
}

// ============================================================================
// TEXT INPUT FORMATTER UNTUK FORM RUPIAH
// ============================================================================
class CurrencyFormatIdr extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String clean = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return newValue.copyWith(text: '');

    String formatted = '';
    int count = 0;
    for (int i = clean.length - 1; i >= 0; i--) {
      formatted = clean[i] + formatted;
      count++;
      if (count == 3 && i > 0) {
        formatted = '.$formatted';
        count = 0;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ============================================================================
// HELPER WAKTU & SAPAAN DINAMIS (Sesuai Spesifikasi HomeScreen)
// ============================================================================
String getSapaanWaktu() {
  final hour = DateTime.now().hour;

  if (hour >= 3 && hour <= 10) {
    return 'Selamat Pagi';
  } else if (hour >= 11 && hour <= 14) {
    return 'Selamat Siang';
  } else if (hour >= 15 && hour <= 17) {
    return 'Selamat Sore';
  } else {
    // Berlaku untuk jam 18-02
    return 'Selamat Malam';
  }
}
