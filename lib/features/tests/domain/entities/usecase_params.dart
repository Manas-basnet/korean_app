import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';

class LoadTestsParams extends Equatable {
  final int page;
  final int pageSize;
  final TestSortType sortType;
  final TestCategory? category;
  final bool forceRefresh;
  final bool loadMore;

  const LoadTestsParams({
    this.page = 0,
    this.pageSize = 5,
    this.sortType = TestSortType.recent,
    this.category,
    this.forceRefresh = false,
    this.loadMore = false,
  });

  LoadTestsParams copyWith({
    int? page,
    int? pageSize,
    TestSortType? sortType,
    TestCategory? category,
    bool? forceRefresh,
    bool? loadMore,
  }) {
    return LoadTestsParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortType: sortType ?? this.sortType,
      category: category ?? this.category,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      loadMore: loadMore ?? this.loadMore,
    );
  }

  @override
  List<Object?> get props => [page, pageSize, sortType, category, forceRefresh, loadMore];
}

class CheckTestPermissionParams extends Equatable {
  final String testId;
  final String? testCreatorUid;

  const CheckTestPermissionParams({
    required this.testId,
    this.testCreatorUid,
  });

  @override
  List<Object?> get props => [testId, testCreatorUid];
}

class RateTestParams extends Equatable {
  final String testId;
  final double rating;

  const RateTestParams({
    required this.testId,
    required this.rating,
  });

  @override
  List<Object?> get props => [testId, rating];
}

class SearchTestsParams extends Equatable {
  final String query;
  final int limit;

  const SearchTestsParams({
    required this.query,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [query, limit];
}

class StartTestSessionParams extends Equatable {
  final String testId;

  const StartTestSessionParams({
    required this.testId,
  });

  @override
  List<Object?> get props => [testId];
}