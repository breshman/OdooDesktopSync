import 'package:flutter/material.dart';

CmpSemanticColor darkSemanticColor = CmpSemanticColor(
  negativeLabel: const Color(0xFFFF5C77),
  criticalLabel: const Color(0xFFFFB300),
  positiveLabel: const Color(0xFF5DC122),
  informativeLabel: const Color(0xFF4DB1FF),
  neutralLabel: const Color(0xFF8396A8),
  // negativeBackground: const Color(0xFFEE3939).withAlpha(0xCC),
  negativeBackground: const Color(0xFFEE3939).withValues(alpha: 20),
  criticalBackground: const Color(0xFFE76500).withValues(alpha: 20),
  positiveBackground: const Color(0xFF36A41D).withValues(alpha: 20),
  informativeBackground: const Color(0xFF1B90FF).withValues(alpha: 20),
  neutralBackground: const Color(0xFF5B738B).withValues(alpha: 20),
);

CmpSemanticColor lightSemanticColor = CmpSemanticColor(
  negativeLabel: const Color(0xFFD20A0A),
  criticalLabel: const Color(0xFFC35500),
  positiveLabel: const Color(0xFF188918),
  informativeLabel: const Color(0xFF0070F2),
  neutralLabel: const Color(0xFF475E75),
  negativeBackground: const Color(0xFF475E75).withValues(alpha: 20),
  criticalBackground: const Color(0xFFE76500).withValues(alpha: 20),
  positiveBackground: const Color(0xFF36A41D).withValues(alpha: 20),
  informativeBackground: const Color(0xFF1B90FF).withValues(alpha: 20),
  neutralBackground: const Color(0xFF5B738B).withValues(alpha: 20),
);

/// Semantic Label
class CmpSemanticColor extends ThemeExtension<CmpSemanticColor> {
  const CmpSemanticColor({
    required this.negativeLabel,
    required this.criticalLabel,
    required this.positiveLabel,
    required this.informativeLabel,
    required this.neutralLabel,
    required this.negativeBackground,
    required this.criticalBackground,
    required this.positiveBackground,
    required this.informativeBackground,
    required this.neutralBackground,
  });

  final Color? negativeLabel;
  final Color? criticalLabel;
  final Color? positiveLabel;
  final Color? informativeLabel;
  final Color? neutralLabel;
  final Color? negativeBackground;
  final Color? criticalBackground;
  final Color? positiveBackground;
  final Color? informativeBackground;
  final Color? neutralBackground;

  @override
  CmpSemanticColor copyWith({
    Color? negativeLabel,
    Color? criticalLabel,
    Color? positiveLabel,
    Color? informativeLabel,
    Color? neutralLabel,
    Color? negativeBackground,
    Color? criticalBackground,
    Color? positiveBackground,
    Color? informativeBackground,
    Color? neutralBackground,
  }) {
    return CmpSemanticColor(
      negativeLabel: negativeLabel ?? this.negativeLabel,
      criticalLabel: criticalLabel ?? this.criticalLabel,
      positiveLabel: positiveLabel ?? this.positiveLabel,
      informativeLabel: informativeLabel ?? this.informativeLabel,
      neutralLabel: neutralLabel ?? this.neutralLabel,
      negativeBackground: negativeBackground ?? this.negativeBackground,
      criticalBackground: criticalBackground ?? this.criticalBackground,
      positiveBackground: positiveBackground ?? this.positiveBackground,
      informativeBackground:
          informativeBackground ?? this.informativeBackground,
      neutralBackground: neutralBackground ?? this.neutralBackground,
    );
  }

  @override
  CmpSemanticColor lerp(ThemeExtension<CmpSemanticColor>? other, double t) {
    if (other is! CmpSemanticColor) {
      return this;
    }
    return CmpSemanticColor(
      negativeLabel: Color.lerp(negativeLabel, other.negativeLabel, t),
      criticalLabel: Color.lerp(criticalLabel, other.criticalLabel, t),
      positiveLabel: Color.lerp(positiveLabel, other.positiveLabel, t),
      informativeLabel: Color.lerp(informativeLabel, other.informativeLabel, t),
      neutralLabel: Color.lerp(neutralLabel, other.neutralLabel, t),
      negativeBackground:
          Color.lerp(negativeBackground, other.negativeBackground, t),
      criticalBackground:
          Color.lerp(criticalBackground, other.criticalBackground, t),
      positiveBackground:
          Color.lerp(positiveBackground, other.positiveBackground, t),
      informativeBackground:
          Color.lerp(informativeBackground, other.informativeBackground, t),
      neutralBackground:
          Color.lerp(neutralBackground, other.neutralBackground, t),
    );
  }

  /// Returns an instance of [CmpSemanticColor] in which the following custom
  /// colors are harmonized with [dynamic]'s [ColorScheme.primary].
  ///
  /// See also:
  ///   * <https://m3.material.io/styles/color/the-color-system/custom-colors#harmonization>
  CmpSemanticColor harmonized(ColorScheme dynamic) {
    return copyWith();
  }
}
