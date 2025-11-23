import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interactive feature highlights that show tooltips pointing to actual UI elements
class FeatureHighlightsScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onDismissAll;
  final List<FeatureHighlight> highlights;

  const FeatureHighlightsScreen({
    super.key,
    required this.onComplete,
    required this.highlights,
    this.onDismissAll,
  });

  @override
  State<FeatureHighlightsScreen> createState() => _FeatureHighlightsScreenState();
}

class _FeatureHighlightsScreenState extends State<FeatureHighlightsScreen> {
  int _currentHighlight = 0;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCurrentHighlight();
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _showCurrentHighlight() {
    _overlayEntry?.remove();

    if (_currentHighlight >= widget.highlights.length) {
      _complete();
      return;
    }

    final highlight = widget.highlights[_currentHighlight];

    _overlayEntry = OverlayEntry(
      builder: (context) => _HighlightOverlay(
        highlight: highlight,
        onNext: _nextHighlight,
        onSkip: _complete,
        onDismissAll: widget.onDismissAll,
        currentIndex: _currentHighlight,
        totalCount: widget.highlights.length,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _nextHighlight() {
    setState(() {
      _currentHighlight++;
    });
    _showCurrentHighlight();
  }

  Future<void> _complete() async {
    _overlayEntry?.remove();
    _overlayEntry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenFeatureHighlights', true);

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Overlay handles all UI
  }
}

class _HighlightOverlay extends StatelessWidget {
  final FeatureHighlight highlight;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onDismissAll;
  final int currentIndex;
  final int totalCount;

  const _HighlightOverlay({
    required this.highlight,
    required this.onNext,
    required this.onSkip,
    required this.currentIndex,
    required this.totalCount,
    this.onDismissAll,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        children: [
          // Spotlight effect on target area
          if (highlight.targetKey.currentContext != null)
            _buildSpotlight(context),

          // Tooltip with arrow
          if (highlight.targetKey.currentContext != null)
            _buildTooltip(context),

          // Progress indicator and controls
          _buildControls(context),
        ],
      ),
    );
  }

  Widget _buildSpotlight(BuildContext context) {
    final RenderBox? renderBox = highlight.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final padding = highlight.spotlightPadding;

    return Positioned(
      left: position.dx - padding,
      top: position.dy - padding,
      child: Container(
        width: size.width + (padding * 2),
        height: size.height + (padding * 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight.accentColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: highlight.accentColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final RenderBox? renderBox = highlight.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // Determine tooltip position (above or below target)
    final isAbove = position.dy > screenSize.height / 2;
    final tooltipTop = isAbove
        ? position.dy - 200 // Position above
        : position.dy + size.height + 20; // Position below

    return Positioned(
      left: 20,
      right: 20,
      top: tooltipTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arrow pointing to target
          if (!isAbove) _buildArrow(highlight.accentColor, pointingUp: true),

          // Tooltip card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlight.accentColor.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon and title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: highlight.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        highlight.icon,
                        color: highlight.accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        highlight.title,
                        style: TextStyle(
                          color: highlight.accentColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  highlight.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Arrow pointing to target
          if (isAbove) _buildArrow(highlight.accentColor, pointingUp: false),
        ],
      ),
    );
  }

  Widget _buildArrow(Color color, {required bool pointingUp}) {
    return CustomPaint(
      size: const Size(24, 12),
      painter: _ArrowPainter(color: color, pointingUp: pointingUp),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalCount,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == currentIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? highlight.accentColor
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip button
                  TextButton(
                    onPressed: onSkip,
                    child: const Text(
                      'Skip Tour',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Next/Done button
                  ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: highlight.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentIndex == totalCount - 1 ? 'Got It!' : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          currentIndex == totalCount - 1
                              ? Icons.check
                              : Icons.arrow_forward,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Dismiss All button
              if (onDismissAll != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onDismissAll,
                  icon: const Icon(Icons.block, size: 16, color: Colors.red),
                  label: const Text(
                    'Don\'t show tutorials again',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool pointingUp;

  _ArrowPainter({required this.color, required this.pointingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (pointingUp) {
      // Arrow pointing up
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      // Arrow pointing down
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}

/// Model for a single feature highlight
class FeatureHighlight {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final double spotlightPadding;

  FeatureHighlight({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor = Colors.blue,
    this.spotlightPadding = 8.0,
  });
}
