import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider to manage loading state globally
final loadingProvider = StateProvider<bool>((ref) => false);

/// Custom loading dialog widget
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Global overlay entry for the loader
OverlayEntry? _loaderEntry;
bool _isLoaderVisible = false;

/// Shows a loading overlay on the screen
void showLoader(BuildContext context) {
  if (_isLoaderVisible) {
    debugPrint('showLoader: Loader already visible, skipping');
    return;
  }

  try {
    _loaderEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.3),
        child: const _LoadingDialog(),
      ),
    );

    Overlay.of(context).insert(_loaderEntry!);
    _isLoaderVisible = true;
    debugPrint('showLoader: Loader shown successfully');
  } catch (e) {
    debugPrint('showLoader error: $e');
    _isLoaderVisible = false;
  }
}

/// Hides the loading overlay
Future<void> hideLoader() async {
  if (!_isLoaderVisible || _loaderEntry == null) {
    debugPrint('hideLoader: Loader not visible, skipping');
    return;
  }

  try {
    _loaderEntry?.remove();
    _loaderEntry = null;
    _isLoaderVisible = false;

    // Small delay to ensure state is properly updated
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('hideLoader: Loader hidden successfully');
  } catch (e) {
    debugPrint('hideLoader error: $e');
    _loaderEntry = null;
    _isLoaderVisible = false;
  }
}
