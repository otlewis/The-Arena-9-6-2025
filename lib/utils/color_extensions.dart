import 'package:flutter/material.dart';

/// Safe color alpha compatibility extension
///
/// Provides a backwards-compatible way to set color opacity that works
/// across all Flutter SDK versions. The newer Color.withOpacity(x)
/// is only available in Flutter 3.22+, while withOpacity(double) works
/// on all versions.
///
/// Usage: color.withOpacity(0.5) instead of color.withOpacity(0.5)
extension ColorAlphaCompat on Color {
  /// Set color opacity (0.0 - 1.0)
  ///
  /// This is a safe shim that uses withOpacity() under the hood,
  /// ensuring compatibility with all Flutter SDK versions.
  Color withAlpha(double opacity) => withOpacity(opacity);
}
