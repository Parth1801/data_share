import 'package:datatransfer/core/constants/app_strings.dart';
import 'package:datatransfer/core/services/shared_prefs_service.dart';
import 'package:datatransfer/core/theme/app_theme.dart';
import 'package:datatransfer/core/theme/theme_provider/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'features/home/presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefsService().init();
  final isDarkMode = SharedPrefsService().isDarkMode;
  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(
          (ref) => ThemeNotifier(isDarkMode ? ThemeMode.dark : ThemeMode.light),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: AppStrings.appName,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: child,
        );
      },
      child: const MainNavigationScreen(),
    );
  }
}
