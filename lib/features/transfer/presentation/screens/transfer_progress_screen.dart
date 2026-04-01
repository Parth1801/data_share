import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:datatransfer/features/transfer/providers/transfer_provider.dart';
import 'package:datatransfer/core/models/file_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransferProgressScreen extends ConsumerWidget {
  const TransferProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transferState = ref.watch(transferProvider);

    final String titlePrefix = transferState.isSending ? 'Sending' : 'Receiving';
    final String statusText = transferState.isCompleted 
        ? '$titlePrefix Complete' 
        : '$titlePrefix...';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(statusText),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          if (transferState.error != null)
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
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                  itemCount: transferState.files.length,
                  itemBuilder: (context, index) {
                    final file = transferState.files[index];
                    double progress = 0.0;
                    if (index < transferState.currentFileIndex) {
                      progress = 1.0;
                    } else if (index == transferState.currentFileIndex) {
                      progress = transferState.currentFileProgress;
                    }
                    return _buildFileTransferItem(context, file, index, progress, isDark);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferHeader(BuildContext context, TransferState state, bool isDark, String prefix) {
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
              file.type == 'Video' ? Icons.video_library : (file.type == 'Photo' ? Icons.image : Icons.insert_drive_file),
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
