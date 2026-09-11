import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // Inter untuk semua teks latin; JetBrains Mono untuk OTP, plat, nominal
  static TextStyle get displayLg => GoogleFonts.inter(
        fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w700,
      );

  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  /// JetBrains Mono — OTP digits, plate numbers, fare values
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500,
      );
}