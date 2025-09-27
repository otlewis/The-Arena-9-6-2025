import 'package:flutter/material.dart';

/// Utility functions for displaying user names in a consistent way across the app.
/// Supports stacking two-word names vertically for better space utilization.
class NameDisplayUtils {
  /// Build a text widget that stacks two-word names vertically.
  /// For names with exactly 2 words and when not marked as small, it will stack them.
  /// Otherwise, it displays the name normally.
  static Widget buildStackedNameText(String name, {
    required double fontSize,
    required Color color,
    required FontWeight fontWeight,
    required TextAlign textAlign,
    required int maxLines,
    bool isSmall = false,
    double height = 1.1,
    bool allowOverflow = false,
  }) {
    final words = name.trim().split(' ');
    
    // If name has exactly 2 words and isn't too small, stack them vertically
    if (words.length == 2 && !isSmall && words[0].isNotEmpty && words[1].isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            words[0],
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: height, // Tight line spacing
            ),
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            words[1],
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: height, // Tight line spacing
            ),
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // For single word names, more than 2 words, or small displays, use regular text
      return Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: allowOverflow ? TextOverflow.visible : TextOverflow.ellipsis,
      );
    }
  }

  /// Checks if a name would benefit from stacking (has exactly 2 words)
  static bool shouldStackName(String name) {
    final words = name.trim().split(' ');
    return words.length == 2 && words[0].isNotEmpty && words[1].isNotEmpty;
  }

  /// Gets the estimated height needed for a name display
  /// Useful for calculating container heights when names might be stacked
  static double getEstimatedHeight(String name, double fontSize, {bool isSmall = false}) {
    if (shouldStackName(name) && !isSmall) {
      // Two lines with tight spacing
      return fontSize * 2.2; // Approximation including line height
    } else {
      // Single line
      return fontSize * 1.2;
    }
  }
}