import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewer extends StatefulWidget {
  final String url;
  final String title;
  
  const WebViewer({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewer> createState() => _WebViewerState();
}

class _WebViewerState extends State<WebViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _currentUrl = '';
  String _pageTitle = '';
  double _loadingProgress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  
  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _pageTitle = widget.title;
    _initializeWebView();
  }
  
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
              _currentUrl = url;
            });
            _updateNavigationState();
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            
            // Get page title
            final title = await _controller.getTitle();
            if (title != null && title.isNotEmpty) {
              setState(() {
                _pageTitle = title;
              });
            }
            _updateNavigationState();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load webpage: ${error.description}'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                    });
                    _refresh();
                  },
                ),
              ),
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            // Always allow navigation within the app
            // Never open external browser
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }
  
  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }
  
  void _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }
  
  void _goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
    }
  }
  
  void _refresh() {
    _controller.reload();
  }
  
  void _share() {
    // Share current URL
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _currentUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL copied to clipboard')),
    );
  }
  
  Widget _buildUrlBar() {
    final theme = Theme.of(context);
    final isSecure = _currentUrl.startsWith('https');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSecure ? Icons.lock : Icons.lock_open,
            size: 16,
            color: isSecure ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentUrl,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied')),
              );
            },
            tooltip: 'Copy URL',
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigationBar() {
    final theme = Theme.of(context);
    
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _canGoBack ? _goBack : null,
            tooltip: 'Back',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _canGoForward ? _goForward : null,
            tooltip: 'Forward',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _share,
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pageTitle,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              Uri.parse(_currentUrl).host,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          _buildUrlBar(),
          Expanded(
            child: Stack(
              children: [
                if (!_hasError)
                  WebViewWidget(controller: _controller),
                if (_hasError)
                  Container(
                    color: Colors.grey[50],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load webpage',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.red[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                              });
                              _refresh();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isLoading && _loadingProgress < 1.0 && !_hasError)
                  Container(
                    color: Colors.white.withValues(alpha: 0.8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _loadingProgress,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading... ${(_loadingProgress * 100).toInt()}%',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildNavigationBar(),
        ],
      ),
    );
  }
}