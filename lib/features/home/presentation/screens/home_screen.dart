import 'package:datatransfer/features/file_selection/presentation/screens/file_selection_screen.dart';
import 'package:datatransfer/features/home/providers/history_provider.dart';
import 'package:datatransfer/features/home/providers/storage_provider.dart';
import 'package:datatransfer/features/transfer/presentation/screens/receive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storageInfo = ref.watch(storageProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: 20.h),
              storageInfo.maybeWhen(
                data: (info) => _buildStorageInfoCard(context, isDark, info),
                orElse: () => _buildStorageInfoCard(context, isDark, null),
              ),
              SizedBox(height: 30.h),
              _buildActionButtons(context),
              SizedBox(height: 30.h),
              _buildRecentFiles(context, isDark, history),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Parth',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {},
              ),
              IconButton(icon: const Icon(Icons.computer), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfoCard(
    BuildContext context,
    bool isDark,
    StorageInfo? info,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                info != null
                    ? '${info.usedSpace.toStringAsFixed(1)} GB / ${info.totalSpace.toStringAsFixed(1)} GB'
                    : 'Loading...',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          SizedBox(
            height: 8.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: LinearProgressIndicator(
                value: info?.usagePercentage ?? 0,
                minHeight: 8.h,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FileSelectionScreen(),
                  ),
                );
              },
              child: _buildActionButton(
                context,
                title: 'Send',
                icon: Icons.arrow_upward_rounded,
                color: Colors.blueAccent,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Navigate to radar/receive screen later
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReceiveScreen(),
                  ),
                );
              },
              child: _buildActionButton(
                context,
                title: 'Receive',
                icon: Icons.arrow_downward_rounded,
                color: Colors.greenAccent.shade700,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      height: 120.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.8 : 0.9),
            color.withOpacity(isDark ? 0.5 : 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFiles(
    BuildContext context,
    bool isDark,
    List<dynamic> history,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Files',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              if (history.isNotEmpty)
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 15.h),
        if (history.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'No recent transfers',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 100.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return GestureDetector(
                  onTap: () async {
                    if (item.path.isNotEmpty) {
                      await OpenFilex.open(item.path);
                    }
                  },
                  child: Container(
                    width: 100.w,
                    margin: EdgeInsets.symmetric(horizontal: 5.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconForType(item.type),
                          size: 32.sp,
                          color: _getColorForType(item.type),
                        ),
                        SizedBox(height: 8.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text(
                            item.name,
                            style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white70 : Colors.grey.shade800),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'photo':
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
      case 'music':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'photo':
      case 'image':
        return Colors.orange;
      case 'video':
        return Colors.redAccent;
      case 'audio':
      case 'music':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }
}
