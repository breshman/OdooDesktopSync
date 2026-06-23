import 'package:flutter/material.dart';

CmpAcentColor lightAcentColor = const CmpAcentColor(
  mango: Color(0xFFA93E00),
  red: Color(0xFFAA0808),
  raspberry: Color(0xFFBA066C),
  pink: Color(0xFFA100C2),
  indigo: Color(0xFF470CED),
  teal: Color(0xFF046C7A),
  green: Color(0xFF256F3A),
  grey: Color(0xFF354A5F),
  blue: Color(0xFF0070F2),
  cmp: Color(0xFF0F456C),
);

CmpAcentColor darkAcentColor = const CmpAcentColor(
  mango: Color(0xFFFFDF72),
  red: Color(0xFFFFB2D2),
  raspberry: Color(0xFFFECBDA),
  pink: Color(0xFFFFAFED),
  indigo: Color(0xFFE2D8FF),
  teal: Color(0xFF64EDD2),
  green: Color(0xFFBDE986),
  grey: Color(0xFFD5DADD),
  blue: Color(0xFFA6E0FF),
  cmp: Color(0xFF0093FF),
);

/// Avatares o iconos categóricos
class CmpAcentColor extends ThemeExtension<CmpAcentColor> {
  const CmpAcentColor({
    required this.mango,
    required this.red,
    required this.raspberry,
    required this.pink,
    required this.indigo,
    required this.teal,
    required this.green,
    required this.grey,
    required this.blue,
    required this.cmp,
  });
  final Color? mango;
  final Color? red;
  final Color? raspberry;
  final Color? pink;
  final Color? indigo;
  final Color? teal;
  final Color? green;
  final Color? grey;
  final Color? blue;
  final Color? cmp;

  @override
  CmpAcentColor copyWith({
    Color? mango,
    Color? red,
    Color? onRed,
    Color? raspberry,
    Color? pink,
    Color? indigo,
    Color? teal,
    Color? green,
    Color? grey,
    Color? blue,
    Color? cmp,
  }) {
    return CmpAcentColor(
      mango: mango ?? this.mango,
      red: red ?? this.red,
      raspberry: raspberry ?? this.raspberry,
      pink: pink ?? this.pink,
      indigo: indigo ?? this.indigo,
      teal: teal ?? this.teal,
      green: green ?? this.green,
      grey: grey ?? this.grey,
      blue: blue ?? this.blue,
      cmp: cmp ?? this.cmp,
    );
  }

  @override
  CmpAcentColor lerp(ThemeExtension<CmpAcentColor>? other, double t) {
    if (other is! CmpAcentColor) {
      return this;
    }
    return CmpAcentColor(
      mango: Color.lerp(mango, other.mango, t),
      red: Color.lerp(red, other.red, t),
      raspberry: Color.lerp(raspberry, other.raspberry, t),
      pink: Color.lerp(pink, other.pink, t),
      indigo: Color.lerp(indigo, other.indigo, t),
      teal: Color.lerp(teal, other.teal, t),
      green: Color.lerp(green, other.green, t),
      grey: Color.lerp(grey, other.grey, t),
      blue: Color.lerp(blue, other.blue, t),
      cmp: Color.lerp(cmp, other.cmp, t),
    );
  }

  /// Returns an instance of [CmpAcentColor] in which the following custom
  /// colors are harmonized with [dynamic]'s [ColorScheme.primary].
  ///
  /// See also:
  ///   * <https://m3.material.io/styles/color/the-color-system/custom-colors#harmonization>
  CmpAcentColor harmonized(ColorScheme dynamic) {
    return copyWith();
  }
}
