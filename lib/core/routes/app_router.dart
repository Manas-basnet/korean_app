import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/di/di.dart';
import 'package:korean_language_app/features/books/presentation/pages/chapter_list_page.dart';
import 'package:korean_language_app/shared/models/test_result.dart';
import 'package:korean_language_app/core/utils/wrapper.dart';
import 'package:korean_language_app/features/admin/presentation/bloc/admin_permission_cubit.dart';
import 'package:korean_language_app/features/admin/presentation/pages/admin_management_page.dart';
import 'package:korean_language_app/features/admin/presentation/pages/admin_signup_page.dart';
import 'package:korean_language_app/features/admin/presentation/pages/migration_page.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:korean_language_app/features/auth/presentation/pages/login_page.dart';
import 'package:korean_language_app/features/auth/presentation/pages/register_page.dart';
import 'package:korean_language_app/features/book_upload/presentation/pages/book_edit_page.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/favorite_books/favorite_books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/pages/books_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/favorite_books_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_viewer_page.dart';
import 'package:korean_language_app/features/book_upload/presentation/pages/upload_books_page.dart';
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
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _booksShellNavigatorKey = GlobalKey<NavigatorState>();
  static final _testsShellNavigatorKey = GlobalKey<NavigatorState>();
  static final _profileShellNavigatorKey = GlobalKey<NavigatorState>();

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

      // Full-screen routes that don't need bottom nav
      GoRoute(
        path: '/pdf-viewer',
        name: 'pdfViewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final pdfFile = state.extra as PDFViewerScreen;
          return PDFViewerScreen(
            pdfFile: pdfFile.pdfFile,
            title: pdfFile.title,
          );
        },
      ),
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

      // Main shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<TestsCubit>(
                create: (context) => sl<TestsCubit>(),
              ),
              BlocProvider<KoreanBooksCubit>(
                create: (context) => sl<KoreanBooksCubit>(),
              ),
              BlocProvider<FavoriteBooksCubit>(
                create: (context) => sl<FavoriteBooksCubit>(),
              ),
              BlocProvider<ProfileCubit>(
                create: (context) => sl<ProfileCubit>(),
              ),
              BlocProvider<TestUploadCubit>(
                create: (context) => sl<TestUploadCubit>(),
              )
            ],
            child: ScaffoldWithBottomNavBar(child: child),
          );
        },
        routes: [
          // Home route
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),

          // Tests shell route with shared TestsCubit
          ShellRoute(
            navigatorKey: _testsShellNavigatorKey,
            builder: (context, state, child) => TestsShell(child: child),
            routes: [
              GoRoute(
                path: '/tests',
                name: 'tests',
                builder: (context, state) => BlocProvider<TestSearchCubit>(
                  create: (context) => sl<TestSearchCubit>(),
                  child: const TestsPage(),
                ),
              ),
              GoRoute(
                path: '${Routes.testTakingBase}/:testId',
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
                path: '/tests/upload',
                name: 'testUpload',
                builder: (context, state) => const TestUploadPage(),
              ),
              GoRoute(
                path: '/tests/edit/:testId',
                name: 'testEdit',
                builder: (context, state) {
                  final testId = state.pathParameters['testId']!;
                  return TestEditPage(testId: testId);
                },
              ),
              GoRoute(
                path: '/tests/results',
                name: 'testResults',
                builder: (context, state) => BlocProvider<TestResultsCubit>(
                  create: (context) => sl<TestResultsCubit>(),
                  child: const TestResultsHistoryPage(),
                ),
              ),
              GoRoute(
                path: '/tests/unpublished',
                name: 'unpublishedTests',
                builder: (context, state) =>
                    BlocProvider<UnpublishedTestsCubit>(
                  create: (context) => sl<UnpublishedTestsCubit>(),
                  child: const UnpublishedTestsPage(),
                ),
              ),
            ],
          ),

          // Books shell route with shared cubits
          ShellRoute(
            navigatorKey: _booksShellNavigatorKey,
            builder: (context, state, child) => BooksShell(child: child),
            routes: [
              GoRoute(
                path: '/books',
                name: 'books',
                builder: (context, state) => BlocProvider<BookSearchCubit>(
                  create: (context) => sl<BookSearchCubit>(),
                  child: const BooksPage(),
                ),
              ),
              GoRoute(
                path: '/books/upload-books',
                name: 'uploadBooks',
                builder: (context, state) => const BookUploadPage(),
              ),
              GoRoute(
                path: '/books/edit-books',
                name: 'editBooks',
                builder: (context, state) {
                  final extra = state.extra as BookEditPage;
                  return BookEditPage(book: extra.book);
                },
              ),
              GoRoute(
                path: '/books/favorite-books',
                name: 'favoriteBooks',
                builder: (context, state) => const FavoriteBooksPage(),
              ),
              GoRoute(
                path: Routes.chapters,
                name: 'chapters',
                builder: (context, state) {
                  final extra = state.extra as ChaptersPage;
                  return ChaptersPage(
                    book: extra.book,
                  );
                } 
              ),
            ],
          ),

          // Profile shell route with shared ProfileCubit
          ShellRoute(
            navigatorKey: _profileShellNavigatorKey,
            builder: (context, state, child) => ProfileShell(child: child),
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: '/profile/language-preferences',
                name: 'languagePreferences',
                builder: (context, state) => const LanguagePreferencePage(),
              ),
              GoRoute(
                path: '/profile/admin-management',
                name: 'adminManagement',
                builder: (context, state) => BlocProvider<AdminPermissionCubit>(
                  create: (context) => sl<AdminPermissionCubit>(),
                  child: const AdminManagementPage(),
                ),
              ),
              GoRoute(
                path: '/profile/admin-management/admin-signup',
                name: 'adminSignup',
                builder: (context, state) => BlocProvider<AdminPermissionCubit>(
                  create: (context) => sl<AdminPermissionCubit>(),
                  child: const AdminSignupPage(),
                ),
              ),
              GoRoute(
                path: '/profile/admin-management/migration-page',
                name: 'migrationPage',
                builder: (context, state) => const MigrationPage(),
              ),
              GoRoute(
                path: '/profile/user-management',
                name: 'userManagement',
                builder: (context, state) => BlocProvider<UserManagementCubit>(
                  create: (context) => sl<UserManagementCubit>(),
                  child: const UserManagementPage(),
                ),
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

  static const tests = '/tests';
  static const testUpload = '/tests/upload';
  static const testResults = '/tests/results';
  static const testResult = '/test-result';
  static const testReview = '/test-review';
  static const unpublishedTests = '/tests/unpublished';
  static const testTakingBase = '/test-taking';

  static const books = '/books';
  static const pdfViewer = '/pdf-viewer';
  static const uploadBooks = '/books/upload-books';
  static const editBooks = '/books/edit-books';
  static const favoriteBooks = '/books/favorite-books';
  static const chapters = '/books/chapters';

  static const profile = '/profile';
  static const languagePreferences = '/profile/language-preferences';
  static const adminManagement = '/profile/admin-management';
  static const adminMigrationPage = '/profile/admin-management/migration-page';
  static const adminSignup = '/profile/admin-management/admin-signup';
  static const userManagement = '/profile/user-management';

  static String testTaking(String testId) => '$testTakingBase/$testId';
  static String testEdit(String testId) => '/tests/edit/$testId';
}

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithBottomNavBar({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final location = GoRouterState.of(context).uri.path;

    final shouldHideBottomNav = location.startsWith(Routes.testTakingBase);

    return BlocListener<UpdateCubit, UpdateState>(
      listener: (context, state) {
        if (state.status == AppUpdateStatus.available) {
          showUpdateBottomSheet(context);
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: shouldHideBottomNav
            ? null
            : BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: colorScheme.surface,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
                showUnselectedLabels: true,
                currentIndex: _calculateSelectedIndex(context),
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
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/tests')) {
      return 1;
    }
    if (location.startsWith('/books')) {
      return 2;
    }
    if (location.startsWith('/profile')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/home');
        break;
      case 1:
        GoRouter.of(context).go('/tests');
        break;
      case 2:
        GoRouter.of(context).go('/books');
        break;
      case 3:
        GoRouter.of(context).go('/profile');
        break;
    }
  }
}