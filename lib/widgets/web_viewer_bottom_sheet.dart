import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  InAppWebViewController? _controller;
  bool _isLoading = true;
  String? _currentUrl;
  String? _currentTitle;
  static final _logger = AppLogger();
  

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _currentTitle = widget.title;
    _logger.info('🌐 Initializing InAppWebView for: ${widget.url}');
  }

  void _refresh() {
    HapticFeedback.lightImpact();
    _controller?.reload();
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
    if (_controller != null && await _controller!.canGoBack()) {
      HapticFeedback.lightImpact();
      _controller!.goBack();
    }
  }

  void _goForward() async {
    if (_controller != null && await _controller!.canGoForward()) {
      HapticFeedback.lightImpact();
      _controller!.goForward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.9,
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
          // Drag handle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
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
          
          // InAppWebView with proper scrolling support
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                  ),
                  Factory<HorizontalDragGestureRecognizer>(
                    () => HorizontalDragGestureRecognizer(),
                  ),
                  Factory<TapGestureRecognizer>(
                    () => TapGestureRecognizer(),
                  ),
                },
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: true,
                  useOnDownloadStart: false,
                  allowsInlineMediaPlayback: true,
                  userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
                  // Enable scrolling
                  disableDefaultErrorPage: false,
                  verticalScrollBarEnabled: true,
                  horizontalScrollBarEnabled: true,
                  useShouldOverrideUrlLoading: false,
                  // Gesture settings for better scrolling
                  disableVerticalScroll: false,
                  disableHorizontalScroll: false,
                  // Additional touch and scroll settings
                  allowsBackForwardNavigationGestures: true,
                  transparentBackground: false,
                ),
                onWebViewCreated: (InAppWebViewController controller) {
                  _controller = controller;
                  _logger.info('🌐 InAppWebView created successfully');
                },
                onProgressChanged: (InAppWebViewController controller, int progress) {
                  _logger.debug('🌐 Loading progress: $progress%');
                },
                onLoadStart: (InAppWebViewController controller, WebUri? url) {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _currentUrl = url?.toString();
                    });
                  }
                  _logger.info('🌐 Page started loading: $url');
                },
                onLoadStop: (InAppWebViewController controller, WebUri? url) async {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _currentUrl = url?.toString();
                    });
                  }
                  _logger.info('🌐 Page finished loading: $url');
                  
                  // Get page title
                  try {
                    final title = await controller.getTitle();
                    if (title != null && title.isNotEmpty && mounted) {
                      setState(() {
                        _currentTitle = title;
                      });
                    }
                  } catch (e) {
                    _logger.warning('🌐 Could not get page title: $e');
                  }
                  
                  // Inject JavaScript to ensure touch scrolling works
                  try {
                    await controller.evaluateJavascript(source: '''
                      document.body.style.webkitOverflowScrolling = 'touch';
                      document.body.style.overflowY = 'auto';
                      document.documentElement.style.overflowY = 'auto';
                      
                      // Enable touch events
                      document.body.style.touchAction = 'manipulation';
                      
                      // Force reflow to apply styles
                      document.body.offsetHeight;
                    ''');
                    _logger.info('🌐 Touch scrolling JavaScript injected successfully');
                  } catch (e) {
                    _logger.warning('🌐 Could not inject touch scrolling JavaScript: $e');
                  }
                },
                onReceivedError: (InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
                  _logger.error('🌐 WebView error: ${error.description}');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}