import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double s4  = 4;
  static const double s6  = 6;
  static const double s8  = 8;
  static const double s12 = 16;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
}

abstract final class AppRadius {
  static const double sm   = 6;
  static const double md   = 12;
  static const double lg   = 20;
  static const double xl   = 28;
  static const double pill = 999;

  static BorderRadius get smAll   => BorderRadius.circular(sm);
  static BorderRadius get mdAll   => BorderRadius.circular(md);
  static BorderRadius get lgAll   => BorderRadius.circular(lg);
  static BorderRadius get xlAll   => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

abstract final class AppElevation {
  /// elev.0 — no shadow (default)
  static const List<BoxShadow> none = [];

  /// elev.1 — cards
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F0F172A), // rgba(15,23,42,.06)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// elev.2 — floating sheets, FAB
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x1F0F172A), // rgba(15,23,42,.12)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}