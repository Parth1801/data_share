import 'package:datatransfer/core/theme/theme_provider/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.hideKeyboardOnTap = true,
    this.useSafeArea = false,
    // 👇 Back handling
    this.canPop,
    this.onPopInvokedWithResult,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool hideKeyboardOnTap;
  final bool useSafeArea;
  final bool? canPop;
  final void Function(bool didPop, Object? result)? onPopInvokedWithResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    Widget content = body;

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    if (hideKeyboardOnTap) {
      content = GestureDetector(
        onTap: () {
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus &&
              currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: content,
      );
    }

    return PopScope(
      canPop: canPop ?? true,
      onPopInvokedWithResult: onPopInvokedWithResult,

      child: Scaffold(
        appBar: appBar,
        body: content,
        backgroundColor:
            backgroundColor ?? AppColors.scaffoldBackground(isDark),
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}
