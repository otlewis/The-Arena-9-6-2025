import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debate_source.dart';
import '../core/logging/app_logger.dart';
import 'web_viewer_bottom_sheet.dart';

class PinnedLinkBanner extends StatelessWidget {
  final DebateSource? pinnedLink;
  final VoidCallback? onUnpin;
  final bool canUnpin;
  static final _logger = AppLogger();

  const PinnedLinkBanner({
    super.key,
    this.pinnedLink,
    this.onUnpin,
    this.canUnpin = false,
  });

  void _openLink(BuildContext context) {
    if (pinnedLink == null) return;
    
    HapticFeedback.lightImpact();
    _logger.info('🔗 Opening pinned link: ${pinnedLink!.url}');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebViewerBottomSheet(
        url: pinnedLink!.url,
        title: pinnedLink!.title,
      ),
    );
  }

  void _copyLink(BuildContext context) {
    if (pinnedLink == null) return;
    
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: pinnedLink!.url));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pinnedLink == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final isSecure = pinnedLink!.url.startsWith('https');
    
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openLink(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Link icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.link,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PINNED LINK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          if (isSecure) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.lock,
                              size: 12,
                              color: Colors.green,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pinnedLink!.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pinnedLink!.sharedByName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Shared by ${pinnedLink!.sharedByName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Copy button
                    IconButton(
                      onPressed: () => _copyLink(context),
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy Link',
                      visualDensity: VisualDensity.compact,
                    ),
                    
                    // Unpin button (only for hosts/moderators)
                    if (canUnpin && onUnpin != null)
                      IconButton(
                        onPressed: onUnpin,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Unpin Link',
                        visualDensity: VisualDensity.compact,
                      ),
                    
                    // Open indicator
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}