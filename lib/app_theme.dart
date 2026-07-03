import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Color tokens (Soft Tech design system) ─────────────────────────────────
abstract class AppColors {
  static const cream      = Color(0xFFF4F1EA);
  static const cream2     = Color(0xFFEBE7DE);
  static const paper      = Color(0xFFFBF9F4);
  static const ink        = Color(0xFF2A2530);
  static const ink2       = Color(0xFF5B5462);
  static const ink3       = Color(0xFF8C8493);
  static const line       = Color(0x1A2A2530); // 10% ink
  static const line2      = Color(0x0D2A2530); // 5% ink

  static const purple     = Color(0xFF8DC9A0); // soft green
  static const purpleDark = Color(0xFF2A7A4B); // deep emerald (primary)
  static const purpleSoft = Color(0xFFE8F5EC); // pale green

  static const pink       = Color(0xFF5BB57A); // medium green
  static const pinkDark   = Color(0xFF3E9E6A); // bright emerald (gradient end)
  static const pinkSoft   = Color(0xFFEDF7F1); // very pale green

  static const blue       = Color(0xFFA8C5E0);
  static const blueDark   = Color(0xFF6E97BC);
  static const blueSoft   = Color(0xFFE5EEF7);

  static const amber      = Color(0xFFF0D4A8);
  static const amberSoft  = Color(0xFFFAEFDD);

  static const mint       = Color(0xFFB8DDC8);
  static const mintSoft   = Color(0xFFE6F2EC);
}

// ── Theme builder ──────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);
  final textTheme =
      GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.purpleDark,
      onPrimary: Colors.white,
      secondary: AppColors.pinkDark,
      onSecondary: Colors.white,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.ink2,
      outline: AppColors.line,
      outlineVariant: AppColors.line2,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink2),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: AppColors.line2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      labelStyle: const TextStyle(color: AppColors.ink3, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.ink3),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.purpleDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.pinkDark),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.pinkDark, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purpleDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 50),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.purpleDark),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.purpleDark,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      subtitleTextStyle: TextStyle(
        color: AppColors.ink2,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line2),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.ink3,
      collapsedIconColor: AppColors.ink3,
      textColor: AppColors.ink,
      collapsedTextColor: AppColors.ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.paper,
        fontSize: 14,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.ink2),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.purpleDark
            : AppColors.ink3,
      ),
    ),
  );
}

// ── SnackBar helpers ────────────────────────────────────────────────────────
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(
      children: [
        const Icon(Icons.sentiment_satisfied_outlined, size: 22, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ],
    ),
    backgroundColor: const Color(0xFF4CAF50),
    behavior: SnackBarBehavior.floating,
  ));
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(
      children: [
        const Icon(Icons.sentiment_very_dissatisfied_outlined, size: 22, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ],
    ),
    backgroundColor: const Color(0xFFE53935),
    behavior: SnackBarBehavior.floating,
  ));
}

// ── Gradient background ─────────────────────────────────────────────────────
class DotGridBackground extends StatelessWidget {
  final Widget child;
  const DotGridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F0E8), Color(0xFFDDEEDE)],
        ),
      ),
      child: child,
    );
  }
}

// ── Gradient primary button (full-width) ────────────────────────────────────
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.purpleDark, AppColors.pinkDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleDark.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient FAB ────────────────────────────────────────────────────────────
class GradientFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const GradientFAB({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.purpleDark, AppColors.pinkDark],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleDark.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: child,
      ),
    );
  }
}
