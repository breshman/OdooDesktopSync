import 'package:flutter/material.dart';

CmpTextColor lightCmpTextColors = const CmpTextColor(
  primaryText: Color(0xFF223548),
  secondaryText: Color(0xFF475E75),
  tertiaryText: Color(0xFF596e83),
  quaternaryText: Color(0xFF778b9f),
);

CmpTextColor darkCmpTextColors = const CmpTextColor(
  primaryText: Color(0xFFF5F6F7),
  secondaryText: Color(0xFFD5DADD),
  tertiaryText: Color(0xFFA9B4BE),
  quaternaryText: Color(0xFF8396A8),
);

/// Defines a set of custom colors, each comprised of 4 complementary tones.
///
/// See also:
///   * <https://m3.material.io/styles/color/the-color-system/custom-colors>
class CmpTextColor extends ThemeExtension<CmpTextColor> {
  const CmpTextColor({
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.quaternaryText,
  });

  /// Contenido de texto principal (por ejemplo, títulos)
  /// Title / Primary text content
  final Color? primaryText;

  /// Contenido de texto secundario (subtítulos, encabezados de sección)
  /// Subtitle / Secondary text content / Section header text
  final Color? secondaryText;

  /// * Contenido de texto terciario (notas a pie de página, estados).
  /// * Footnotes / Statuses / Tertiary text content / Placeholder text
  final Color? tertiaryText;

  /// Iconos y símbolos no interactivos
  /// Symbols / Icons
  final Color? quaternaryText;

  /// Primary Button Labels & Icons

  @override
  CmpTextColor copyWith({
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? quaternaryText,
  }) {
    return CmpTextColor(
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      quaternaryText: quaternaryText ?? this.quaternaryText,
    );
  }

  @override
  CmpTextColor lerp(ThemeExtension<CmpTextColor>? other, double t) {
    if (other is! CmpTextColor) {
      return this;
    }
    return CmpTextColor(
      primaryText: Color.lerp(primaryText, other.primaryText, t),
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t),
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t),
      quaternaryText: Color.lerp(quaternaryText, other.quaternaryText, t),
    );
  }

  /// Returns an instance of [CmpTextColor] in which the following custom
  /// colors are harmonized with [dynamic]'s [ColorScheme.primary].
  ///
  /// See also:
  ///   * <https://m3.material.io/styles/color/the-color-system/custom-colors#harmonization>
  CmpTextColor harmonized(ColorScheme dynamic) {
    return copyWith();
  }
}
