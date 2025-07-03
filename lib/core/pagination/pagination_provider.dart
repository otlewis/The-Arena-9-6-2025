import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pagination_provider.freezed.dart';

/// Pagination state for lists
@freezed
class PaginationState<T> with _$PaginationState<T> {
  const factory PaginationState({
    @Default([]) List<T> items,
    @Default(false) bool isLoading,
    @Default(false) bool hasError,
    @Default(false) bool hasReachedEnd,
    @Default(0) int currentPage,
    @Default(20) int pageSize,
    String? errorMessage,
  }) = _PaginationState<T>;
  
  const PaginationState._();
  
  bool get isEmpty => items.isEmpty && !isLoading;
  bool get canLoadMore => !isLoading && !hasError && !hasReachedEnd;
}

/// Generic pagination notifier
abstract class PaginationNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginationNotifier() : super(const PaginationState());

  /// Load the first page of data
  Future<void> loadInitial() async {
    if (state.isLoading) return;
    
    state = state.copyWith(
      isLoading: true,
      hasError: false,
      errorMessage: null,
    );

    try {
      final items = await fetchPage(0, state.pageSize);
      state = state.copyWith(
        isLoading: false,
        items: items,
        currentPage: 0,
        hasReachedEnd: items.length < state.pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load the next page of data
  Future<void> loadMore() async {
    if (!state.canLoadMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final newItems = await fetchPage(nextPage, state.pageSize);
      
      state = state.copyWith(
        isLoading: false,
        items: [...state.items, ...newItems],
        currentPage: nextPage,
        hasReachedEnd: newItems.length < state.pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresh the data (reload from beginning)
  Future<void> refresh() async {
    state = const PaginationState();
    await loadInitial();
  }

  /// Retry after error
  Future<void> retry() async {
    if (state.items.isEmpty) {
      await loadInitial();
    } else {
      await loadMore();
    }
  }

  /// Abstract method to fetch data for a specific page
  Future<List<T>> fetchPage(int page, int pageSize);
}

/// Paginated list widget helpers
class PaginationHelpers {
  /// Check if we should load more data based on scroll position
  static bool shouldLoadMore(
    ScrollNotification notification,
    double threshold,
  ) {
    if (notification is! ScrollUpdateNotification) return false;
    
    final metrics = notification.metrics;
    final remaining = metrics.maxScrollExtent - metrics.pixels;
    final screenHeight = metrics.viewportDimension;
    
    return remaining < screenHeight * threshold;
  }

  /// Create a scroll listener for pagination
  static bool Function(ScrollNotification) createScrollListener({
    required VoidCallback onLoadMore,
    double threshold = 0.8,
  }) {
    return (ScrollNotification notification) {
      if (shouldLoadMore(notification, threshold)) {
        onLoadMore();
      }
      return false;
    };
  }
}

/// Pagination widget wrapper
class PaginatedListView<T> extends StatelessWidget {
  const PaginatedListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.separatorBuilder,
    this.padding,
    this.physics,
  });

  final PaginationState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty && state.hasError) {
      return errorBuilder?.call(context, state.errorMessage ?? 'Unknown error') ??
          _defaultErrorWidget(context);
    }

    if (state.isEmpty && !state.isLoading) {
      return emptyBuilder?.call(context) ?? _defaultEmptyWidget(context);
    }

    if (state.isEmpty && state.isLoading) {
      return loadingBuilder?.call(context) ?? _defaultLoadingWidget(context);
    }

    Widget listView = ListView.separated(
      padding: padding,
      physics: physics,
      itemCount: state.items.length + (state.canLoadMore ? 1 : 0),
      separatorBuilder: separatorBuilder ?? (_, __) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          // Load more indicator
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return itemBuilder(context, state.items[index], index);
      },
    );

    listView = NotificationListener<ScrollNotification>(
      onNotification: PaginationHelpers.createScrollListener(
        onLoadMore: onLoadMore,
      ),
      child: listView,
    );

    if (onRefresh != null) {
      listView = RefreshIndicator(
        onRefresh: onRefresh!,
        child: listView,
      );
    }

    return listView;
  }

  Widget _defaultEmptyWidget(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No items found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.errorMessage ?? 'Unknown error',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onLoadMore,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _defaultLoadingWidget(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }
}