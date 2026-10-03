import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accents
  static const Color primary = Color(0xFF2563EB); // Vibrant Blue
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);

  // Backgrounds & Surfaces (Light)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  
  // Backgrounds & Surfaces (Dark)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);

  // Financial Status Accents
  // Emerald / Success (Sudah Ditransfer)
  static const Color emeraldBg = Color(0xFFECFDF5);
  static const Color emeraldBorder = Color(0xFFA7F3D0);
  static const Color emeraldText = Color(0xFF047857);
  static const Color emeraldDarkText = Color(0xFF34D399);

  // Amber / Warning (Menunggu Payout)
  static const Color amberBg = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFDE68A);
  static const Color amberText = Color(0xFFB45309);
  static const Color amberDarkText = Color(0xFFFBBF24);

  // Indigo / Action (Hak Dev Hari Ini / Siap Cair)
  static const Color indigoBg = Color(0xFFEEF2FF);
  static const Color indigoBorder = Color(0xFFC7D2FE);
  static const Color indigoText = Color(0xFF4338CA);
  static const Color indigoDarkText = Color(0xFF818CF8);

  // Slate / Neutral (Total Hak Dev Terkumpul)
  static const Color slateBg = Color(0xFFF1F5F9);
  static const Color slateBorder = Color(0xFFCBD5E1);
  static const Color slateText = Color(0xFF334155);

  // Typography
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Error / Destructive
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
}
