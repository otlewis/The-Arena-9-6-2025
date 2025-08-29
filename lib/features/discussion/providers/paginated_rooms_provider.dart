import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pagination/pagination_provider.dart';
import '../../../services/appwrite_service.dart';
import '../../../core/logging/app_logger.dart';

/// Paginated notifier for debate discussion rooms
class PaginatedRoomsNotifier extends PaginationNotifier<Map<String, dynamic>> {
  final AppwriteService _appwriteService = AppwriteService();

  @override
  Future<List<Map<String, dynamic>>> fetchPage(int pageIndex, int pageSize) async {
    try {
      AppLogger().debug('Fetching rooms page $pageIndex with size $pageSize');
      
      final offset = pageIndex * pageSize;
      final rooms = await _appwriteService.getDebateDiscussionRoomsPaginated(
        limit: pageSize,
        offset: offset,
      );
      
      AppLogger().debug('Fetched ${rooms.length} rooms for page $pageIndex');
      return rooms;
    } catch (e) {
      AppLogger().error('Error fetching rooms page $pageIndex: $e');
      rethrow;
    }
  }
}

/// Provider for paginated debate discussion rooms
final paginatedRoomsProvider = StateNotifierProvider<PaginatedRoomsNotifier, PaginationState<Map<String, dynamic>>>(
  (ref) => PaginatedRoomsNotifier(),
);