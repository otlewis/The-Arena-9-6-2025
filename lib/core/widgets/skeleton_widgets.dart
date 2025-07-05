import 'package:flutter/material.dart';

/// Skeleton loading widgets to show content structure immediately
class SkeletonWidgets {
  
  /// Profile card skeleton
  static Widget profileCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                _SkeletonItem.circular(size: 60),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonItem.rect(width: 120, height: 20),
                      SizedBox(height: 8),
                      _SkeletonItem.rect(width: 200, height: 16),
                      SizedBox(height: 4),
                      _SkeletonItem.rect(width: 80, height: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatSkeleton(),
                _buildStatSkeleton(),
                _buildStatSkeleton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Arena room card skeleton
  static Widget arenaRoomCard() {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SkeletonItem.rect(width: 60, height: 20),
                Spacer(),
                _SkeletonItem.circular(size: 24),
              ],
            ),
            SizedBox(height: 12),
            _SkeletonItem.rect(width: double.infinity, height: 24),
            SizedBox(height: 8),
            _SkeletonItem.rect(width: 250, height: 16),
            SizedBox(height: 16),
            Row(
              children: [
                _SkeletonItem.circular(size: 32),
                SizedBox(width: 8),
                _SkeletonItem.circular(size: 32),
                SizedBox(width: 8),
                _SkeletonItem.circular(size: 32),
                Spacer(),
                _SkeletonItem.rect(width: 80, height: 32, borderRadius: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Club card skeleton
  static Widget clubCard() {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            _SkeletonItem.circular(size: 50),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonItem.rect(width: 150, height: 18),
                  SizedBox(height: 8),
                  _SkeletonItem.rect(width: 200, height: 14),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      _SkeletonItem.rect(width: 60, height: 12),
                      SizedBox(width: 16),
                      _SkeletonItem.rect(width: 80, height: 12),
                    ],
                  ),
                ],
              ),
            ),
            _SkeletonItem.rect(width: 24, height: 24, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  /// Message card skeleton
  static Widget messageCard() {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SkeletonItem.circular(size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonItem.rect(width: 120, height: 16),
                      SizedBox(height: 4),
                      _SkeletonItem.rect(width: 80, height: 12),
                    ],
                  ),
                ),
                _SkeletonItem.rect(width: 60, height: 12),
              ],
            ),
            SizedBox(height: 12),
            _SkeletonItem.rect(width: double.infinity, height: 18),
            SizedBox(height: 8),
            _SkeletonItem.rect(width: 250, height: 16),
            SizedBox(height: 12),
            Row(
              children: [
                _SkeletonItem.rect(width: 80, height: 28, borderRadius: 14),
                SizedBox(width: 8),
                _SkeletonItem.rect(width: 60, height: 28, borderRadius: 14),
                SizedBox(width: 8),
                _SkeletonItem.rect(width: 90, height: 28, borderRadius: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// List skeleton with multiple items
  static Widget list({
    required Widget Function() itemBuilder,
    int itemCount = 5,
  }) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(),
    );
  }

  /// Grid skeleton
  static Widget grid({
    required Widget Function() itemBuilder,
    int itemCount = 6,
    int crossAxisCount = 2,
  }) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(),
    );
  }

  static Widget _buildStatSkeleton() {
    return const Column(
      children: [
        _SkeletonItem.rect(width: 40, height: 24),
        SizedBox(height: 4),
        _SkeletonItem.rect(width: 60, height: 14),
      ],
    );
  }
}

/// Individual skeleton item with shimmer animation
class _SkeletonItem extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircular;

  const _SkeletonItem.rect({
    required this.width,
    required this.height,
    this.borderRadius = 4,
  }) : isCircular = false;

  const _SkeletonItem.circular({
    required double size,
  }) : width = size,
       height = size,
       borderRadius = 0,
       isCircular = true;

  @override
  State<_SkeletonItem> createState() => _SkeletonItemState();
}

class _SkeletonItemState extends State<_SkeletonItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.isCircular 
              ? BorderRadius.circular(widget.width / 2)
              : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value * 2, 0),
              end: Alignment(-1.0 + _animation.value * 2 + 0.7, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[200]!,
                Colors.grey[300]!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton screen wrapper for smooth transitions
class SkeletonScreen extends StatelessWidget {
  final Widget skeleton;
  final Widget content;
  final bool isLoading;
  final Duration fadeInDuration;

  const SkeletonScreen({
    super.key,
    required this.skeleton,
    required this.content,
    required this.isLoading,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: fadeInDuration,
      child: isLoading
        ? skeleton
        : content,
    );
  }
}