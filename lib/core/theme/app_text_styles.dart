import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 30,
    height: 1.15,
    letterSpacing: -1.0,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static TextStyle get title => GoogleFonts.inter(
    fontSize: 16,
    height: 1.3,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 14, height: 1.5, color: AppColors.ink);
  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppColors.muted);
  static TextStyle get button =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);
}
