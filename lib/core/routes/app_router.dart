import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/di/di.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';
import 'package:korean_language_app/features/books/presentation/pages/chapter_list_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_reading_page.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_search/vocabulary_search_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/pages/vocabularies_page.dart';
import 'package:korean_language_app/features/vocabularies/presentation/pages/vocabulary_chapter_list_page.dart';
import 'package:korean_language_app/features/vocabularies/presentation/pages/vocabulary_study_page.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/bloc/vocabulary_upload_cubit.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/vocabulary_edit_page.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/vocabulary_upload_page.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/features/admin/presentation/bloc/admin_permission_cubit.dart';
import 'package:korean_language_app/features/admin/presentation/pages/admin_management_page.dart';
import 'package:korean_language_app/features/admin/presentation/pages/admin_signup_page.dart';
import 'package:korean_language_app/features/admin/presentation/pages/migration_page.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:korean_language_app/features/auth/presentation/pages/login_page.dart';
import 'package:korean_language_app/features/auth/presentation/pages/register_page.dart';
import 'package:korean_language_app/features/home/presentation/pages/home_page.dart';
import 'package:korean_language_app/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:korean_language_app/features/profile/presentation/pages/language_preference_page.dart';
import 'package:korean_language_app/features/profile/presentation/pages/profile_page.dart';
import 'package:korean_language_app/features/test_results/presentation/bloc/test_results_cubit.dart';
import 'package:korean_language_app/features/test_upload/presentation/bloc/test_upload_cubit.dart';
import 'package:korean_language_app/features/test_upload/presentation/pages/test_edit_page.dart';
import 'package:korean_language_app/features/test_results/presentation/pages/test_result_page.dart';
import 'package:korean_language_app/features/test_results/presentation/pages/test_results_history_page.dart';
import 'package:korean_language_app/features/test_results/presentation/pages/test_review_page.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_search/test_search_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/tests_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/pages/test_taking_page.dart';
import 'package:korean_language_app/features/test_upload/presentation/pages/test_upload_page.dart';
import 'package:korean_language_app/features/tests/presentation/pages/tests_page.dart';
import 'package:korean_language_app/features/unpublished_tests/presentation/bloc/unpublished_tests_cubit.dart';
import 'package:korean_language_app/features/unpublished_tests/presentation/pages/unpublished_tests_page.dart';
import 'package:korean_language_app/features/user_management/presentation/bloc/user_management_cubit.dart';
import 'package:korean_language_app/features/user_management/presentation/pages/user_management_page.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/pages/book_upload_page.dart';
import 'package:korean_language_app/features/book_upload/presentation/pages/book_edit_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/books_page.dart';
import 'package:korean_language_app/shared/presentation/connectivity/bloc/connectivity_cubit.dart';
import 'package:korean_language_app/shared/presentation/update/bloc/update_cubit.dart';
import 'package:korean_language_app/shared/presentation/update/widgets/update_bottomsheet.dart';
import 'package:korean_language_app/shared/presentation/widgets/splash/splash_screen.dart';

class AppRouter {
  static final AppRouter _instance = AppRouter._internal();

  AppRouter._internal();

  factory AppRouter() {
    return _instance;
  }

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _homeNavigatorKey = GlobalKey<NavigatorState>();
  static final _testsNavigatorKey = GlobalKey<NavigatorState>();
  static final _booksNavigatorKey = GlobalKey<NavigatorState>();
  static final _vocabulariesNavigatorKey = GlobalKey<NavigatorState>();
  static final _profileNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authCubit = context.read<AuthCubit>();
      final authState = authCubit.state;

      if (authState is AuthInitial) {
        return Routes.splash;
      }

      final isLoggedIn =
          authState is Authenticated || authState is AuthAnonymousSignIn;

      if (authState is AuthLoading) {
        final isGoingToSplash = state.matchedLocation == Routes.splash;
        return isGoingToSplash ? null : Routes.splash;
      }

      if (authState is AuthError) {
        final isGoingToAuth = [
          Routes.login,
          Routes.register,
          Routes.forgotPassword,
          Routes.adminSignup
        ].contains(state.matchedLocation);
        return isGoingToAuth ? null : Routes.login;
      }

      final isGoingToLogin = state.matchedLocation == Routes.login;
      final isGoingToRegister = state.matchedLocation == Routes.register;
      final isGoingToForgotPassword =
          state.matchedLocation == Routes.forgotPassword;
      final isGoingToSplash = state.matchedLocation == Routes.splash;
      final isGoingToAdminSignup =
          state.matchedLocation == Routes.adminManagement + Routes.adminSignup;
      final isGoingToAuth = isGoingToLogin ||
          isGoingToRegister ||
          isGoingToForgotPassword ||
          isGoingToAdminSignup;

      if (isGoingToSplash && authState is! AuthLoading) {
        return isLoggedIn ? Routes.home : Routes.login;
      }

      if (!isLoggedIn) {
        return isGoingToAuth ? null : Routes.login;
      }

      if (isLoggedIn && isGoingToAuth) {
        return Routes.home;
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // Test result routes (outside main navigation)
      GoRoute(
        path: '/test-result',
        name: 'testResult',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final result = state.extra as TestResult;
          return BlocProvider<TestResultsCubit>(
            create: (context) => sl<TestResultsCubit>(),
            child: TestResultPage(result: result),
          );
        },
      ),
      GoRoute(
        path: '/test-review',
        name: 'testReview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final result = state.extra as TestResult;
          return BlocProvider<TestsCubit>(
            create: (context) => sl<TestsCubit>(),
            child: TestReviewPage(testResult: result),
          );
        },
      ),

      // Book reading routes (outside main navigation for direct access)
      GoRoute(
        path: '/book/:bookId/chapters',
        name: 'bookChapters',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return ChapterListPage(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/book/:bookId/chapter/:chapterIndex',
        name: 'chapterReading',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapterIndex = int.parse(state.pathParameters['chapterIndex']!);
          
          return PdfReadingPage(
            bookId: bookId,
            chapterIndex: chapterIndex,
          );
        },
      ),

      // Vocabulary routes (outside main navigation)
      GoRoute(
        path: '/vocabulary/:vocabularyId/chapters',
        name: 'vocabularyChapters',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final vocabularyId = state.pathParameters['vocabularyId']!;
          return VocabularyChapterListPage(vocabularyId: vocabularyId);
        },
      ),
      GoRoute(
        path: '/vocabulary/:vocabularyId/chapter/:chapterIndex',
        name: 'vocabularyChapterReading',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final vocabularyId = state.pathParameters['vocabularyId']!;
          final chapterIndex = int.parse(state.pathParameters['chapterIndex']!);
          return VocabularyStudyPage(vocabularyId: vocabularyId, chapterIndex: chapterIndex);
        },
      ),
      



      // Main stateful shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Home branch
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),

          // Tests branch
          StatefulShellBranch(
            navigatorKey: _testsNavigatorKey,
            routes: [
              ShellRoute(
                builder: (context, state, child) => MultiBlocProvider(
                  providers: [
                    BlocProvider<TestsCubit>(
                      create: (context) => sl<TestsCubit>(),
                    ),
                    BlocProvider<TestSearchCubit>(
                      create: (context) => sl<TestSearchCubit>(),
                    ),
                    BlocProvider<TestUploadCubit>(
                      create: (context) => sl<TestUploadCubit>(),
                    ),
                  ],
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: '/tests',
                    name: 'tests',
                    builder: (context, state) => const TestsPage(),
                    routes: [
                      GoRoute(
                        path: 'taking/:testId',
                        name: 'testTaking',
                        builder: (context, state) {
                          final testId = state.pathParameters['testId']!;
                          return BlocProvider<TestSessionCubit>(
                            create: (context) => sl<TestSessionCubit>(),
                            child: TestTakingPage(testId: testId),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'upload',
                        name: 'testUpload',
                        builder: (context, state) => const TestUploadPage(),
                      ),
                      GoRoute(
                        path: 'edit/:testId',
                        name: 'testEdit',
                        builder: (context, state) {
                          final testId = state.pathParameters['testId']!;
                          return TestEditPage(testId: testId);
                        },
                      ),
                      GoRoute(
                        path: 'results',
                        name: 'testResults',
                        builder: (context, state) =>
                            BlocProvider<TestResultsCubit>(
                          create: (context) => sl<TestResultsCubit>(),
                          child: const TestResultsHistoryPage(),
                        ),
                      ),
                      GoRoute(
                        path: 'unpublished',
                        name: 'unpublishedTests',
                        builder: (context, state) =>
                            BlocProvider<UnpublishedTestsCubit>(
                          create: (context) => sl<UnpublishedTestsCubit>(),
                          child: const UnpublishedTestsPage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Books branch
          StatefulShellBranch(
            navigatorKey: _booksNavigatorKey,
            routes: [
              ShellRoute(
                builder: (context, state, child) => MultiBlocProvider(
                  providers: [
                    BlocProvider<BookSearchCubit>(
                      create: (context) => sl<BookSearchCubit>(),
                    ),
                    BlocProvider<BookUploadCubit>(
                      create: (context) => sl<BookUploadCubit>(),
                    ),
                  ],
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: '/books',
                    name: 'books',
                    builder: (context, state) => const BooksPage(),
                    routes: [
                      GoRoute(
                        path: 'upload',
                        name: 'bookUpload',
                        builder: (context, state) => const BookUploadPage(),
                      ),
                      GoRoute(
                        path: 'edit/:bookId',
                        name: 'bookEdit',
                        builder: (context, state) {
                          final bookId = state.pathParameters['bookId']!;
                          return BookEditPage(bookId: bookId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Vocabularies branch
          StatefulShellBranch(
            navigatorKey: _vocabulariesNavigatorKey,
            routes: [
              ShellRoute(
                builder: (context, state, child) => MultiBlocProvider(
                  providers: [
                    BlocProvider<VocabularySearchCubit>(
                      create: (context) => sl<VocabularySearchCubit>(),
                    ),
                    BlocProvider<VocabularyUploadCubit>(
                      create: (context) => sl<VocabularyUploadCubit>(),
                    ),
                  ],
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: '/vocabularies',
                    name: 'vocabularies',
                    builder: (context, state) => const VocabulariesPage(),
                    routes: [
                      GoRoute(
                        path: 'upload',
                        name: 'vocabularyUpload',
                        builder: (context, state) => const VocabularyUploadPage(),
                      ),
                      GoRoute(
                        path: 'edit/:vocabularyId',
                        name: 'vocabularyEdit',
                        builder: (context, state) {
                          final vocabularyId = state.pathParameters['vocabularyId']!;
                          return VocabularyEditPage(vocabularyId: vocabularyId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Profile branch
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              ShellRoute(
                builder: (context, state, child) => BlocProvider<ProfileCubit>(
                  create: (context) => sl<ProfileCubit>(),
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: '/profile',
                    name: 'profile',
                    builder: (context, state) => const ProfilePage(),
                    routes: [
                      GoRoute(
                        path: 'language-preferences',
                        name: 'languagePreferences',
                        builder: (context, state) =>
                            const LanguagePreferencePage(),
                      ),
                      GoRoute(
                        path: 'admin-management',
                        name: 'adminManagement',
                        builder: (context, state) =>
                            BlocProvider<AdminPermissionCubit>(
                          create: (context) => sl<AdminPermissionCubit>(),
                          child: const AdminManagementPage(),
                        ),
                        routes: [
                          GoRoute(
                            path: 'admin-signup',
                            name: 'adminSignup',
                            builder: (context, state) =>
                                BlocProvider<AdminPermissionCubit>(
                              create: (context) => sl<AdminPermissionCubit>(),
                              child: const AdminSignupPage(),
                            ),
                          ),
                          GoRoute(
                            path: 'migration-page',
                            name: 'migrationPage',
                            builder: (context, state) => const MigrationPage(),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'user-management',
                        name: 'userManagement',
                        builder: (context, state) =>
                            BlocProvider<UserManagementCubit>(
                          create: (context) => sl<UserManagementCubit>(),
                          child: const UserManagementPage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';


  //Tests routes
  static const tests = '/tests';
  static const testUpload = '/tests/upload';
  static const testResults = '/tests/results';
  static const testResult = '/test-result';
  static const testReview = '/test-review';
  static const unpublishedTests = '/tests/unpublished';
  static const testTakingBase = '/tests/taking';

  // Books routes
  static const books = '/books';
  static const bookUpload = '/books/upload';

  // Vocabularies routes
  static const vocabularies = '/vocabularies';
  static const vocabularyUpload = '/vocabularies/upload';

  // Profile routes
  static const profile = '/profile';
  static const languagePreferences = '/profile/language-preferences';
  static const adminManagement = '/profile/admin-management';
  static const adminMigrationPage = '/profile/admin-management/migration-page';
  static const adminSignup = '/profile/admin-management/admin-signup';
  static const userManagement = '/profile/user-management';

  // Helper methods for dynamic routes
  static String testTaking(String testId) => '/tests/taking/$testId';
  static String testEdit(String testId) => '/tests/edit/$testId';
  static String bookEdit(String bookId) => '/books/edit/$bookId';
  static String vocabularyEdit(String vocabularyId) => '/vocabularies/edit/$vocabularyId';
  
  // Book reading routes (at root level for direct access)
  static String bookChapters(String bookId) => '/book/$bookId/chapters';
  static String bookChapterReading(String bookId, int chapterIndex) => '/book/$bookId/chapter/$chapterIndex';

  static String vocabularyChapters(String vocabularyId) => '/vocabulary/$vocabularyId/chapters';
  static String vocabularyChapterReading(String vocabularyId, int chapterIndex) => '/vocabulary/$vocabularyId/chapter/$chapterIndex';
}

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithBottomNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final location = GoRouterState.of(context).uri.path;

    final shouldHideBottomNav = location.startsWith('/tests/taking') ||
        location.startsWith('/book/') ||
        location == '/test-result' ||
        location == '/test-review';

    return MultiBlocListener(
      listeners: [
        BlocListener<UpdateCubit, UpdateState>(
          listener: (context, state) {
            if (state.status == AppUpdateStatus.available) {
              showUpdateBottomSheet(context);
            }
          },
        ),
      ],
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<ConnectivityCubit, ConnectivityState>(
              builder: (context, state) {
                if (state is ConnectivityDisconnected) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.error.withValues(alpha: 0.9),
                          colorScheme.error,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: colorScheme.onError,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: colorScheme.onError,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (!shouldHideBottomNav)
              BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: colorScheme.surface,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor:
                    colorScheme.onSurface.withValues(alpha: 0.6),
                showUnselectedLabels: true,
                currentIndex: navigationShell.currentIndex,
                onTap: (index) => _onItemTapped(index, context),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.quiz_rounded),
                    label: 'Tests',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu_book_rounded),
                    label: 'Books',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.book_rounded),
                    label: 'Vocabulary',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}