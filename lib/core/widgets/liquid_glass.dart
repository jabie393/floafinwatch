import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Apple iOS Liquid Glass container powered by liquid_glass_easy
/// Features:
/// 1. Real-time background refraction blur & shader distortion
/// 2. Clean, ultra-delicate 360° hairline border (atas, kanan, kiri, bawah)
/// 3. Continuous rounded rectangle (squircle/capsule) geometry
/// 4. Soft physical contact shadows & ambient liquid backdrop
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tintColor;
  final double opacity;
  final bool hasSpecularBorder;
  final bool hasChromaticAberration;
  final Color? borderColor;
  final List<BoxShadow>? customShadows;
  final VoidCallback? onTap;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding,
    this.margin,
    this.blur = 18,
    this.tintColor,
    this.opacity = 0.72,
    this.hasSpecularBorder = true,
    this.hasChromaticAberration = true,
    this.borderColor,
    this.customShadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In dark mode: deep obsidian crystal tint; in light mode: pristine crystal
    final glassColor = isDark
        ? (tintColor ?? const Color(0xFF1E293B)).withValues(alpha: 0.65)
        : (tintColor ?? Colors.white).withValues(alpha: 0.75);

    // Subtle, delicate hairline border color (prevents harsh thick lines)
    final effectiveBorderColor = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.65));

    Widget content = padding != null ? Padding(padding: padding!, child: child) : child;

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    // Shader shape with zero internal border width to prevent uneven double-stroking
    final shape = LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: borderRadius,
      borderWidth: 0.0,
      borderType: const OpticalBorder(borderSaturation: 0, ambientIntensity: 0),
    );

    final style = LiquidGlassStyle(
      shape: shape,
      appearance: LiquidGlassAppearance(
        color: glassColor,
        blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
        shadow: customShadows == null
            ? LiquidGlassShadow(
                blur: 16,
                opacity: isDark ? 0.35 : 0.08,
                color: Colors.black,
                offset: const Offset(0, 6),
              )
            : null,
      ),
      refraction: LiquidGlassRefraction(
        distortion: 0.10,
        distortionWidth: 24,
        chromaticAberration: hasChromaticAberration ? 0.003 : 0.0,
      ),
    );

    Widget lens = LiquidGlassLens(
      style: style,
      child: content,
    );

    // Single, uniform, ultra-fine 0.85px hairline glass border across all 4 edges (atas, kanan, bawah, kiri)
    if (hasSpecularBorder) {
      lens = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: effectiveBorderColor,
            width: 0.85,
          ),
        ),
        child: lens,
      );
    }

    if (customShadows != null) {
      lens = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: customShadows,
        ),
        child: lens,
      );
    }

    if (margin != null) {
      lens = Padding(padding: margin!, child: lens);
    }

    return lens;
  }
}

/// Liquid Glass Pill / Bubble powered by liquid_glass_easy
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? activeColor;
  final double borderRadius;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.isSelected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.activeColor,
    this.borderRadius = 30,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = activeColor ?? AppColors.primary;

    final pillColor = isSelected
        ? (isDark
              ? primary.withValues(alpha: 0.32)
              : const Color(0xFFE2EDFE).withValues(alpha: 0.95))
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.40));

    final effectiveBorderColor = isSelected
        ? (isDark ? primary.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.85))
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.50));

    Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    final shape = LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: borderRadius,
      borderWidth: 0.0,
      borderType: const OpticalBorder(borderSaturation: 0, ambientIntensity: 0),
    );

    final style = LiquidGlassStyle(
      shape: shape,
      appearance: LiquidGlassAppearance(
        color: pillColor,
        blur: const LiquidGlassBlur(sigmaX: 14, sigmaY: 14),
        shadow: isSelected
            ? LiquidGlassShadow(
                blur: 10,
                opacity: isDark ? 0.30 : 0.15,
                color: primary,
                offset: const Offset(0, 3),
              )
            : null,
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.08,
        distortionWidth: 18,
        chromaticAberration: 0.0025,
      ),
    );

    Widget pill = LiquidGlassLens(
      style: style,
      child: content,
    );

    // Delicate 0.85px hairline border for pill
    pill = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: 0.85,
        ),
      ),
      child: pill,
    );

    return pill;
  }
}

/// Ambient glowing backdrop mesh to make liquid glass refractive and luminous
class AmbientLiquidBackdrop extends StatelessWidget {
  final Widget child;

  const AmbientLiquidBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base solid background
        Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        ),

        // Glowing Ambient Orb 1 (Top Right - Electric Sky Blue)
        Positioned(
          top: -70,
          right: -70,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF2563EB).withValues(alpha: 0.25),
                        const Color(0xFF2563EB).withValues(alpha: 0.0),
                      ]
                    : [
                        const Color(0xFF60A5FA).withValues(alpha: 0.35),
                        const Color(0xFF60A5FA).withValues(alpha: 0.0),
                      ],
              ),
            ),
          ),
        ),

        // Glowing Ambient Orb 2 (Middle Left - Vivid Iris / Violet)
        Positioned(
          top: 280,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF7C3AED).withValues(alpha: 0.18),
                        const Color(0xFF7C3AED).withValues(alpha: 0.0),
                      ]
                    : [
                        const Color(0xFFA78BFA).withValues(alpha: 0.28),
                        const Color(0xFFA78BFA).withValues(alpha: 0.0),
                      ],
              ),
            ),
          ),
        ),

        // Glowing Ambient Orb 3 (Bottom Right - Soft Rose / Emerald)
        Positioned(
          bottom: 120,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF059669).withValues(alpha: 0.15),
                        const Color(0xFF059669).withValues(alpha: 0.0),
                      ]
                    : [
                        const Color(0xFFF472B6).withValues(alpha: 0.20),
                        const Color(0xFFF472B6).withValues(alpha: 0.0),
                      ],
              ),
            ),
          ),
        ),

        // Main content
        child,
      ],
    );
  }
}
