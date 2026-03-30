import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/file_item.dart';

// StateNotifier that holds a simple List of selected files
class SelectedFilesNotifier extends Notifier<List<FileItem>> {
  @override
  List<FileItem> build() => [];

  void toggleFile(FileItem file) {
    // If it's already selected, remove it. Otherwise, add it.
    if (state.any((item) => item.id == file.id)) {
      state = state.where((item) => item.id != file.id).toList();
    } else {
      state = [...state, file];
    }
  }

  void clearFiles() {
    state = [];
  }
}

// The Provider you will watch in your UI
final selectedFilesProvider =
    NotifierProvider<SelectedFilesNotifier, List<FileItem>>(() {
      return SelectedFilesNotifier();
    });
