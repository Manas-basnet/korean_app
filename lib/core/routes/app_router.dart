import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/di/di.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/bloc/book_editing_cubit.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/pages/book_editing_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/chapter_list_page.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
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
  static final _homeNavigatorKey = GlobalKey<NavigatorState>();
  static final _testsNavigatorKey = GlobalKey<NavigatorState>();
  static final _booksNavigatorKey = GlobalKey<NavigatorState>();
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

      // Full-screen routes that don't need bottom nav
      GoRoute(
        path: Routes.bookEditingPage,
        name: 'bookEditingPage',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final pdfFile = state.extra as BookEditingPage;
          return BlocProvider<BookEditingCubit>(
            create: (context) => sl<BookEditingCubit>(),
            child: BookEditingPage(
              sourcePdf: pdfFile.sourcePdf,
              onChaptersGenerated: pdfFile.onChaptersGenerated,
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.pdfViewer,
        name: 'pdfViewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as PDFViewerScreen;
          return PDFViewerScreen(
            pdfFile: extra.pdfFile,
            title: extra.title,
            chapter: extra.chapter,
            book: extra.book,
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
                        builder: (context, state) => BlocProvider<TestResultsCubit>(
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
                    BlocProvider<KoreanBooksCubit>(
                      create: (context) => sl<KoreanBooksCubit>(),
                    ),
                    BlocProvider<FavoriteBooksCubit>(
                      create: (context) => sl<FavoriteBooksCubit>(),
                    ),
                    BlocProvider<BookSearchCubit>(
                      create: (context) => sl<BookSearchCubit>(),
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
                        path: 'upload-books',
                        name: 'uploadBooks',
                        builder: (context, state) => const BookUploadPage(),
                      ),
                      GoRoute(
                        path: 'edit-books',
                        name: 'editBooks',
                        builder: (context, state) {
                          final extra = state.extra as BookEditPage;
                          return BookEditPage(book: extra.book);
                        },
                      ),
                      GoRoute(
                        path: 'favorite-books',
                        name: 'favoriteBooks',
                        builder: (context, state) => const FavoriteBooksPage(),
                      ),
                      GoRoute(
                        path: 'chapters',
                        name: 'chapters',
                        builder: (context, state) {
                          final extra = state.extra as ChaptersPage;
                          return ChaptersPage(book: extra.book);
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
                        builder: (context, state) => const LanguagePreferencePage(),
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
  static const bookEditingPage = '/book-editing-page';
  static const home = '/home';

  static const tests = '/tests';
  static const testUpload = '/tests/upload';
  static const testResults = '/tests/results';
  static const testResult = '/test-result';
  static const testReview = '/test-review';
  static const unpublishedTests = '/tests/unpublished';
  static const testTakingBase = '/tests/taking';

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

  static String testTaking(String testId) => '/tests/taking/$testId';
  static String testEdit(String testId) => '/tests/edit/$testId';
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

    final shouldHideBottomNav = location.startsWith('/tests/taking');

    return BlocListener<UpdateCubit, UpdateState>(
      listener: (context, state) {
        if (state.status == AppUpdateStatus.available) {
          showUpdateBottomSheet(context);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: shouldHideBottomNav
            ? null
            : BottomNavigationBar(
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
                    icon: Icon(Icons.person_rounded),
                    label: 'Profile',
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