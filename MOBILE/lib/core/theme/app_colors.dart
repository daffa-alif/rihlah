import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary (brand green) ─────────────────────────
  static const primary500 = Color(0xFF0E7C5A); // CTAs, brand surfaces
  static const primary600 = Color(0xFF0A6347); // pressed states
  static const primary100 = Color(0xFFDCEFE6); // tint backgrounds, chips

  // ── Accent (saffron) ──────────────────────────────
  static const accent500 = Color(0xFFF4A11C); // promotions, surge badges
  static const accent100 = Color(0xFFFCE7C2);

  // ── Semantic ──────────────────────────────────────
  static const success500 = Color(0xFF16A34A);
  static const warning500 = Color(0xFFF59E0B);
  static const danger500  = Color(0xFFDC2626); // SOS, cancel, errors
  static const info500    = Color(0xFF2563EB);

  // ── Ink (neutral) ─────────────────────────────────
  static const ink900 = Color(0xFF0F172A); // primary text
  static const ink700 = Color(0xFF334155); // secondary text
  static const ink500 = Color(0xFF64748B); // tertiary, placeholders
  static const ink400 = Color(0xFF94A3B8);
  static const ink300 = Color(0xFFCBD5E1); // borders, dividers
  static const ink100 = Color(0xFFF1F5F9); // surface alt
  static const ink0   = Color(0xFFFFFFFF);

  
}