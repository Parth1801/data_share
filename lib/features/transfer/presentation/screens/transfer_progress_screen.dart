import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:datatransfer/features/transfer/providers/transfer_provider.dart';
import 'package:datatransfer/features/transfer/providers/discovery_provider.dart';
import 'package:datatransfer/features/file_selection/providers/selected_files_provider.dart';
import 'package:datatransfer/core/models/file_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransferProgressScreen extends ConsumerWidget {
  const TransferProgressScreen({super.key});

  Future<void> _resetAndGoHome(BuildContext context, WidgetRef ref) async {
    // Clear states first
    ref.read(transferProvider.notifier).reset();
    ref.read(selectedFilesProvider.notifier).clearFiles();
    
    // Don't await fullReset if it blocks the UI navigation
    ref.read(discoveryProvider.notifier).fullReset();
    
    if (context.mounted) {
      // Force pop back to home, ignoring PopScope if necessary
      // Using pushAndRemoveUntil is more reliable here than popUntil if PopScope is strict
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transferState = ref.watch(transferProvider);
    print(
      'TransferProgressScreen: Current State - isSending: ${transferState.isSending}, Files: ${transferState.files.length}',
    );

    final isPaused = transferState.isPaused;
    final String titlePrefix = transferState.isSending
        ? 'Sending'
        : 'Receiving';
    
    String statusText = transferState.isCompleted
        ? '$titlePrefix Complete'
        : '$titlePrefix...';
    if (isPaused) statusText = 'Transfer Paused';

    return PopScope(
      canPop: transferState.isCompleted || transferState.error != null || isPaused,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation(context, ref);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(statusText),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitConfirmation(context, ref),
          ),
          actions: [
            if (transferState.isTransferring && transferState.isSending)
              TextButton.icon(
                onPressed: () => _showCancelConfirmation(context, ref),
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                label: const Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      body: Column(
        children: [
          if (isPaused)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.pause_circle_filled, color: Colors.orange),
                   SizedBox(width: 10.w),
                   Expanded(
                     child: Text(
                       'Connection lost. Progress has been saved. Reconnect to resume.',
                       style: TextStyle(color: Colors.orange[800], fontSize: 13.sp),
                     ),
                   ),
                ],
              ),
            ),
          if (transferState.error != null && !isPaused)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                transferState.error!,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
              ),
            ),
          _buildTransferHeader(context, transferState, isDark, titlePrefix),
          Expanded(
            child: transferState.files.isEmpty
                ? const Center(child: Text('Waiting for files...'))
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 20.h,
                    ),
                    itemCount: transferState.files.length,
                    itemBuilder: (context, index) {
                      final file = transferState.files[index];
                      double progress = 0.0;
                      if (index < transferState.currentFileIndex) {
                        progress = 1.0;
                      } else if (index == transferState.currentFileIndex) {
                        progress = transferState.currentFileProgress;
                      }
                      return _buildFileTransferItem(
                        context,
                        file,
                        index,
                        progress,
                        isDark,
                      );
                    },
                  ),
          ),
          // Done / Go Back button shown when transfer completes or errors
          if (transferState.isCompleted || transferState.error != null || isPaused)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 30.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isPaused 
                    ? () => Navigator.of(context).popUntil((route) => route.isFirst)
                    : () => _resetAndGoHome(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused ? Colors.orange : theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    transferState.isCompleted ? 'Done' : (isPaused ? 'Exit to Home' : 'Go Back'),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit & Pause?'),
        content: const Text(
          'The transfer will be paused and progress saved. You can resume later by selecting the same files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetAndGoHome(context, ref);
            },
            child: const Text('Exit & Pause'),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete & Cancel?'),
        content: const Text(
          'This will PERMANENTLY cancel the transfer and DELETE the partial file from the receiver side. This cannot be resumed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Transfer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(transferProvider.notifier).cancelTransfer();
              _resetAndGoHome(context, ref);
            },
            child: const Text('Delete & Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferHeader(
    BuildContext context,
    TransferState state,
    bool isDark,
    String prefix,
  ) {
    return Container(
      padding: EdgeInsets.all(25.w),
      margin: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.isCompleted ? '$prefix Complete' : '$prefix...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    '${state.files.length} Files',
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${state.speedMBs.toStringAsFixed(1)} MB/s',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          LinearProgressIndicator(
            value: state.overallProgress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8.h,
            borderRadius: BorderRadius.circular(10.r),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
              Text(
                '${(state.overallProgress * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileTransferItem(
    BuildContext context,
    FileItem file,
    int index,
    double progress,
    bool isDark,
  ) {
    bool isDone = progress >= 1.0;
    bool isPending = progress == 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              file.type == 'Video'
                  ? Icons.video_library
                  : (file.type == 'Photo'
                        ? Icons.image
                        : Icons.insert_drive_file),
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${file.sizeMB.toStringAsFixed(1)} MB',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 5.h),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone
                              ? Colors.green
                              : Theme.of(context).primaryColor,
                        ),
                        minHeight: 4.h,
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      isDone
                          ? 'Done'
                          : (isPending
                                ? 'Waiting'
                                : '${(progress * 100).toInt()}%'),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDone ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
