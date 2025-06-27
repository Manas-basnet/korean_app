import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/di/di.dart' as di;
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_editing/book_editing_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/presentation/theme/constants/app_theme.dart';
import 'package:korean_language_app/firebase_options.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/shared/presentation/connectivity/bloc/connectivity_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/theme/bloc/theme_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/widgets/snackbar_widget.dart';
import 'package:korean_language_app/shared/presentation/update/bloc/update_cubit.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as shorebird;
import 'package:url_strategy/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    setPathUrlStrategy();
  }

  await initializeFirebase();

  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SnackBarCubit>(
          create: (context) => di.sl<SnackBarCubit>(),
        ),
        BlocProvider<AuthCubit>(
          create: (context) => di.sl<AuthCubit>(),
        ),
        BlocProvider<ThemeCubit>(
          create: (context) => di.sl<ThemeCubit>(),
        ),
        BlocProvider<FileUploadCubit>(
          create: (context) => di.sl<FileUploadCubit>(),
        ),
        BlocProvider<ConnectivityCubit>(
          create: (context) => di.sl<ConnectivityCubit>(),
        ),
        BlocProvider<LanguagePreferenceCubit>(
          create: (context) => di.sl<LanguagePreferenceCubit>(),
        ),
        BlocProvider<BookEditingCubit>(
          create: (context) => di.sl<BookEditingCubit>(),
        ),
        BlocProvider<UpdateCubit>(
          create: (context) =>
              UpdateCubit(shorebird.ShorebirdUpdater())..checkForUpdates(),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) {
          return (previous.runtimeType != current.runtimeType) &&
              (current is Authenticated ||
                  current is Unauthenticated ||
                  current is AuthAnonymousSignIn ||
                  current is AuthLoading);
        },
        listener: (context, state) {
          AppRouter.router.refresh();
        },
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Korean Test App',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              routerConfig: AppRouter.router,
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                return SnackBarWidget(
                  child: child ?? const SizedBox(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}