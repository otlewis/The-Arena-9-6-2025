import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkSharingBottomSheet extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final Function(String url, String? title)? onShareLink;
  
  const LinkSharingBottomSheet({
    super.key,
    required this.roomId,
    required this.currentUserId,
    this.onShareLink,
  });

  @override
  State<LinkSharingBottomSheet> createState() => _LinkSharingBottomSheetState();
}

class _LinkSharingBottomSheetState extends State<LinkSharingBottomSheet> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  
  bool _isLoading = false;
  String? _previewTitle;
  String? _previewDescription;
  bool _hasValidUrl = false;
  
  final List<Map<String, String>> _recentLinks = [
    {
      'url': 'https://docs.flutter.dev',
      'title': 'Flutter Documentation',
      'type': 'docs'
    },
    {
      'url': 'https://github.com',
      'title': 'GitHub',
      'type': 'code'
    },
    {
      'url': 'https://youtube.com',
      'title': 'YouTube',
      'type': 'video'
    },
  ];

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    
    // Auto-focus and check clipboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
      _urlFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    final isValid = _isValidUrl(url);
    
    if (isValid != _hasValidUrl) {
      setState(() {
        _hasValidUrl = isValid;
      });
      
      if (isValid) {
        _loadPreview(url);
      } else {
        _clearPreview();
      }
    }
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    final uri = Uri.tryParse(url);
    return uri != null && 
           uri.hasScheme && 
           (uri.scheme == 'http' || uri.scheme == 'https') &&
           uri.hasAuthority;
  }

  void _loadPreview(String url) {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate loading preview (in real app, you'd fetch actual metadata)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _urlController.text.trim() == url) {
        setState(() {
          _isLoading = false;
          _previewTitle = _generateTitleFromUrl(url);
          _previewDescription = 'Link preview for shared content';
          // Preview image cleared
        });
      }
    });
  }

  String _generateTitleFromUrl(String url) {
    final uri = Uri.parse(url);
    final domain = uri.host.replaceAll('www.', '');
    return domain.split('.').first.toUpperCase();
  }

  void _clearPreview() {
    setState(() {
      _isLoading = false;
      _previewTitle = null;
      _previewDescription = null;
      // Preview image cleared
    });
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();
      
      if (text != null && _isValidUrl(text)) {
        _urlController.text = text;
      }
    } catch (e) {
      // Clipboard access failed, ignore
    }
  }

  void _shareLink() {
    final url = _urlController.text.trim();
    final title = _titleController.text.trim().isNotEmpty 
        ? _titleController.text.trim()
        : _previewTitle;
    
    if (_hasValidUrl) {
      widget.onShareLink?.call(url, title);
      Navigator.pop(context);
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link shared with debate participants'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectRecentLink(Map<String, String> link) {
    _urlController.text = link['url']!;
    _titleController.text = link['title']!;
  }

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'video': return Icons.play_circle_outline;
      case 'docs': return Icons.description_outlined;
      case 'code': return Icons.code;
      case 'image': return Icons.image_outlined;
      default: return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.share, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share Link',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Share documents, videos, or resources',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // URL Input
                  TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Paste or type URL',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintText: 'https://example.com',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.link, color: Colors.blue),
                      suffixIcon: _urlController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[400]),
                              onPressed: () {
                                _urlController.clear();
                                _clearPreview();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Optional Title Input
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title (optional)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintText: 'Custom title for the link',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.title, color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _shareLink(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Link Preview
                  if (_isLoading || _previewTitle != null) ...[
                    const Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: _isLoading
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading preview...',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_previewTitle != null)
                                  Text(
                                    _previewTitle!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (_previewDescription != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _previewDescription!,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  _urlController.text,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Recent Links
                  const Text(
                    'Recent Links',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recentLinks.map((link) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _getTypeIcon(link['type']!),
                          color: Colors.blue,
                        ),
                        title: Text(
                          link['title']!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          link['url']!,
                          style: TextStyle(color: Colors.grey[400]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.open_in_new, color: Colors.grey[400]),
                              onPressed: () => _openLink(link['url']!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.blue),
                              onPressed: () => _selectRecentLink(link),
                            ),
                          ],
                        ),
                        tileColor: Colors.grey[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 80), // Space for floating button
                ],
              ),
            ),
          ),
          
          // Floating Share Button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _hasValidUrl ? _shareLink : null,
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text(
                'Share Link',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasValidUrl ? Colors.blue : Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

