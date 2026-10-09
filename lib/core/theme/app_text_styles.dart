import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get h1 => GoogleFonts.sourceSerif4(
      fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink);
  static TextStyle get h2 => GoogleFonts.sourceSerif4(
      fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ink);
  static TextStyle get title => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink);
  static TextStyle get body => GoogleFonts.inter(
      fontSize: 14, height: 1.4, color: AppColors.ink);
  static TextStyle get caption => GoogleFonts.inter(
      fontSize: 12, color: AppColors.muted);
  static TextStyle get button => GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w600);
}