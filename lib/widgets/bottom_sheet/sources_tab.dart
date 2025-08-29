import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/debate_source.dart';
import '../../services/livekit_material_sync_service.dart';
import '../../services/appwrite_service.dart';
import '../../services/pinned_link_service.dart';
import '../../core/logging/app_logger.dart';
import '../web_viewer_bottom_sheet.dart';

class SourcesTab extends StatefulWidget {
  final String roomId;
  final String userId;
  final List<DebateSource> sources;
  final LiveKitMaterialSyncService syncService;
  final AppwriteService appwriteService;
  final VoidCallback? onSourceAdded;
  final bool isHost;
  
  const SourcesTab({
    super.key,
    required this.roomId,
    required this.userId,
    required this.sources,
    required this.syncService,
    required this.appwriteService,
    this.onSourceAdded,
    this.isHost = false,
  });

  @override
  State<SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<SourcesTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isAddingSource = false;
  static final _logger = AppLogger();
  late PinnedLinkService _pinnedLinkService;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _pinnedLinkService = PinnedLinkService(
      appwrite: widget.appwriteService,
      roomId: widget.roomId,
      userId: widget.userId,
    );
  }
  
  @override
  void dispose() {
    _pinnedLinkService.dispose();
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }
  
  Future<void> _addSource() async {
    final url = _urlController.text.trim();
    final title = _titleController.text.trim();
    
    _logger.info('🔗 Adding source: $title -> $url');
    
    if (url.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both URL and title')),
      );
      return;
    }
    
    // Validate and normalize URL
    String normalizedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalizedUrl = 'https://$url';
    }
    
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL (e.g., google.com or https://google.com)')),
      );
      return;
    }
    
    _logger.info('🔗 Normalized URL: $normalizedUrl');
    
    try {
      await widget.syncService.shareSource(normalizedUrl, title);
      _logger.info('✅ Source shared to sync service successfully');
      
      _urlController.clear();
      _titleController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus(); // Hide keyboard
        setState(() {
          _isAddingSource = false;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source shared successfully')),
        );
      }
      
      // Notify parent to reload sources
      _logger.info('📝 Calling onSourceAdded callback to refresh list');
      widget.onSourceAdded?.call();
    } catch (e) {
      _logger.error('❌ Failed to share source: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share source: $e')),
        );
      }
    }
  }
  
  void _openSourceInApp(DebateSource source) {
    HapticFeedback.lightImpact();
    _logger.info('🌐 Opening source in app: ${source.url}');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebViewerBottomSheet(
        url: source.url,
        title: source.title,
      ),
    );
  }
  
  Future<void> _shareSource(DebateSource source) async {
    try {
      _logger.info('📌 Sharing source: ${source.title}');
      await _pinnedLinkService.pinLink(
        source.url,
        source.title,
        description: source.description,
      );
      
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${source.title}" shared with all participants'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.error('❌ Error sharing source: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share source: $e')),
        );
      }
    }
  }
  
  Widget _buildSourceCard(DebateSource source) {
    final theme = Theme.of(context);
    final isSecure = source.url.startsWith('https');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _openSourceInApp(source),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: source.isPinned
                      ? theme.primaryColor.withValues(alpha: 0.2)
                      : theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: source.isPinned
                      ? Border.all(color: theme.primaryColor, width: 2)
                      : null,
                ),
                child: Center(
                  child: source.isPinned
                      ? Icon(Icons.push_pin, color: theme.primaryColor, size: 20)
                      : (source.faviconUrl != null
                          ? Image.network(
                              source.faviconUrl!,
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.language, color: theme.primaryColor),
                            )
                          : Icon(Icons.language, color: theme.primaryColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            source.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: source.isPinned ? FontWeight.bold : FontWeight.w600,
                              color: source.isPinned ? theme.primaryColor : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (source.isPinned) ...[ 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'PINNED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isSecure && !source.isPinned)
                          const Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.green,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (source.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        source.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (source.sharedByName != null)
                          Text(
                            'Shared by ${source.sharedByName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        const Spacer(),
                        if (widget.isHost && !source.isPinned)
                          IconButton(
                            onPressed: () => _shareSource(source),
                            icon: const Icon(Icons.share, size: 18),
                            tooltip: 'Share with All',
                            visualDensity: VisualDensity.compact,
                          ),
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
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAddSourceForm() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_link, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Share New Source',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (widget.isHost)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'As host, you can share sources with all participants in the room',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'example.com (https:// will be added automatically)',
                prefixIcon: const Icon(Icons.link, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Source title',
                prefixIcon: const Icon(Icons.title, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSource(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingSource = false;
                    });
                    _urlController.clear();
                    _titleController.clear();
                    FocusScope.of(context).unfocus(); // Hide keyboard
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addSource,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    if (widget.sources.isEmpty && !_isAddingSource) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No sources shared',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.isHost
                  ? 'Share web sources with all participants'
                  : 'Share web sources to support your arguments',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isAddingSource = true;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Share Source'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        if (_isAddingSource)
          Expanded(child: _buildAddSourceForm())
        else ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isAddingSource = true;
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Share New Source'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: widget.sources.length,
              itemBuilder: (context, index) {
                return _buildSourceCard(widget.sources[index]);
              },
            ),
          ),
        ],
      ],
    );
  }
}