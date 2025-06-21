import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';

class TestsLoadResult extends Equatable {
  final List<TestItem> tests;
  final bool hasMore;
  final int currentPage;
  final bool isFromCache;
  final int totalCount;

  const TestsLoadResult({
    required this.tests,
    required this.hasMore,
    required this.currentPage,
    required this.isFromCache,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [tests, hasMore, currentPage, isFromCache, totalCount];
}

class TestPermissionResult extends Equatable {
  final bool canEdit;
  final bool canDelete;
  final bool canView;
  final String reason;

  const TestPermissionResult({
    required this.canEdit,
    required this.canDelete,
    required this.canView,
    this.reason = '',
  });

  @override
  List<Object?> get props => [canEdit, canDelete, canView, reason];
}

class TestSearchResult extends Equatable {
  final List<TestItem> tests;
  final String query;
  final int resultCount;
  final bool isFromCache;

  const TestSearchResult({
    required this.tests,
    required this.query,
    required this.resultCount,
    required this.isFromCache,
  });

  @override
  List<Object?> get props => [tests, query, resultCount, isFromCache];
}

class TestSessionStartResult extends Equatable {
  final TestSession session;
  final TestItem test;
  final bool wasViewed;

  const TestSessionStartResult({
    required this.session,
    required this.test,
    required this.wasViewed,
  });

  @override
  List<Object?> get props => [session, test, wasViewed];
}