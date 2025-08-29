import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/logging/app_logger.dart';

class WebViewerBottomSheet extends StatefulWidget {
  final String url;
  final String title;

  const WebViewerBottomSheet({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewerBottomSheet> createState() => _WebViewerBottomSheetState();
}

class _WebViewerBottomSheetState extends State<WebViewerBottomSheet> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _currentUrl;
  String? _currentTitle;
  static final _logger = AppLogger();

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _currentTitle = widget.title;
    _initializeWebView();
  }

  void _initializeWebView() {
    _logger.info('🌐 Initializing WebView for: ${widget.url}');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            _logger.debug('🌐 Loading progress: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            _logger.info('🌐 Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _logger.info('🌐 Page finished loading: $url');
            
            // Get page title
            _controller.getTitle().then((title) {
              if (title != null && title.isNotEmpty && mounted) {
                setState(() {
                  _currentTitle = title;
                });
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            _logger.error('🌐 WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _refresh() {
    HapticFeedback.lightImpact();
    _controller.reload();
  }

  void _copyUrl() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _currentUrl ?? widget.url));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goBack() async {
    if (await _controller.canGoBack()) {
      HapticFeedback.lightImpact();
      _controller.goBack();
    }
  }

  void _goForward() async {
    if (await _controller.canGoForward()) {
      HapticFeedback.lightImpact();
      _controller.goForward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle area - more prominent
              GestureDetector(
                onPanUpdate: (details) {
                  // Allow the DraggableScrollableSheet to handle drag gestures in this area
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Drag here to resize',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Header with title and controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Back/Forward buttons
                    Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_back, size: 20),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Back',
                        ),
                        IconButton(
                          onPressed: _goForward,
                          icon: const Icon(Icons.arrow_forward, size: 20),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Forward',
                        ),
                      ],
                    ),
                    
                    // Title and URL
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTitle ?? widget.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_currentUrl != null)
                            Text(
                              Uri.parse(_currentUrl!).host,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    Row(
                      children: [
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Refresh',
                          ),
                        IconButton(
                          onPressed: _copyUrl,
                          icon: const Icon(Icons.copy, size: 20),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Copy URL',
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 20),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // WebView
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: GestureDetector(
                    // Prevent drag gestures from being consumed by the DraggableScrollableSheet
                    // when interacting with the WebView
                    onVerticalDragStart: (_) {}, // Empty handler to consume the event
                    onVerticalDragUpdate: (_) {}, // Empty handler to consume the event
                    onVerticalDragEnd: (_) {}, // Empty handler to consume the event
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        // Prevent the DraggableScrollableSheet from handling scroll events
                        return true;
                      },
                      child: WebViewWidget(controller: _controller),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}