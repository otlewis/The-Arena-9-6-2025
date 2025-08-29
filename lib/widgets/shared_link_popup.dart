import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debate_source.dart';
import '../core/logging/app_logger.dart';
import 'web_viewer_bottom_sheet.dart';

class SharedLinkPopup extends StatelessWidget {
  final DebateSource sharedLink;
  final VoidCallback? onDismiss;
  static final _logger = AppLogger();

  const SharedLinkPopup({
    super.key,
    required this.sharedLink,
    this.onDismiss,
  });

  void _openLink(BuildContext context) {
    HapticFeedback.lightImpact();
    _logger.info('🔗 Opening shared link: ${sharedLink.url}');
    
    // Dismiss this popup first
    Navigator.of(context).pop();
    
    // Then show the web viewer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebViewerBottomSheet(
        url: sharedLink.url,
        title: sharedLink.title,
      ),
    );
  }

  void _copyLink(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: sharedLink.url));
    
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
    final theme = Theme.of(context);
    final isSecure = sharedLink.url.startsWith('https');
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark 
              ? const Color(0xFF1a1a2e) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.8),
                    theme.primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Link Shared!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (sharedLink.sharedByName != null)
                          Text(
                            'by ${sharedLink.sharedByName}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Link preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              size: 18,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sharedLink.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSecure)
                              const Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.green,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Uri.parse(sharedLink.url).host,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (sharedLink.description != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            sharedLink.description!,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyLink(context),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy Link'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: theme.primaryColor),
                            foregroundColor: theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _openLink(context),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}