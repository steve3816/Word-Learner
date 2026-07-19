import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette (Layer 1): raw colors, named by how they look ──────────────────
// Only colors actually in use — nothing here is decorative/unused.
abstract class AppPalette {
  // Warm cream/charcoal neutrals
  static const linen         = Color(0xFFF4F1EA);
  static const linenDark     = Color(0xFFEBE7DE);
  static const ivory         = Color(0xFFFBF9F4);
  static const white         = Color(0xFFFFFFFF);
  static const charcoal      = Color(0xFF2A2530);
  static const charcoalSoft  = Color(0xFF5B5462);
  static const charcoalMuted = Color(0xFF8C8493);
  static const charcoal10    = Color(0x1A2A2530); // charcoal @ 10% alpha
  static const charcoal5     = Color(0x0D2A2530); // charcoal @ 5% alpha

  // Greens
  static const emerald       = Color(0xFF2A7A4B); // deep emerald
  static const emeraldBright = Color(0xFF3E9E6A); // bright emerald
  static const emeraldPale   = Color(0xFFE8F5EC); // pale mint
}

// ── Semantic tokens (Layer 2): named by business role ───────────────────────
abstract class AppColors {
  static const background      = AppPalette.linen;      // scaffold/app bar
  static const surface         = AppPalette.white;        // cards, fields, sheets
  static const surfaceAlt      = AppPalette.linenDark;    // secondary chip/button fill
  static const surfaceSelected = AppPalette.emeraldPale;  // selected list row

  static const textPrimary   = AppPalette.charcoal;
  static const textSecondary = AppPalette.charcoalSoft;
  static const textMuted     = AppPalette.charcoalMuted;

  static const border       = AppPalette.charcoal10;
  static const borderSubtle = AppPalette.charcoal5;

  static const primary   = AppPalette.emerald;
  static const secondary = AppPalette.emeraldBright;
}

// ── Theme builder ──────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);
  final textTheme =
      GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSubtle,
    ),
    scaffoldBackgroundColor: AppColors.background,
    // Opt out of predictive back: any predictive-back builder live-tracks the
    // drag gesture, which always renders the current page as a moving/draggable
    // layer. The system edge-swipe-to-go-back gesture still works without it —
    // it just plays this fixed pop transition instead of a live preview.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
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
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
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
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      subtitleTextStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.borderSubtle),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.textMuted,
      collapsedIconColor: AppColors.textMuted,
      textColor: AppColors.textPrimary,
      collapsedTextColor: AppColors.textPrimary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.surface,
        fontSize: 14,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textMuted,
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
            colors: [AppColors.primary, AppColors.secondary],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
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
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
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
