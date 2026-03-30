import 'package:datatransfer/features/file_selection/providers/selected_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../transfer/presentation/screens/radar_scan_screen.dart';
import '../widgets/file_list_tab.dart';

class FileSelectionScreen extends ConsumerStatefulWidget {
  const FileSelectionScreen({super.key});

  @override
  ConsumerState<FileSelectionScreen> createState() =>
      _FileSelectionScreenState();
}

class _FileSelectionScreenState extends ConsumerState<FileSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleFileSelection() {
    // This will be replaced by actual file selection logic using selectedFilesProvider
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedFiles = ref.watch(selectedFilesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Send Files'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Apps'),
            Tab(text: 'Photos'),
            Tab(text: 'Music'),
            Tab(text: 'Videos'),
            Tab(text: 'Files'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              FileListTab(
                type: 'History',
                onToggleSelection: _toggleFileSelection,
              ),
              FileListTab(
                type: 'Apps',
                onToggleSelection: _toggleFileSelection,
              ),
              FileListTab(
                type: 'Photos',
                onToggleSelection: _toggleFileSelection,
                isGrid: true,
              ),
              FileListTab(
                type: 'Music',
                onToggleSelection: _toggleFileSelection,
              ),
              FileListTab(
                type: 'Videos',
                onToggleSelection: _toggleFileSelection,
                isGrid: true,
              ),
              FileListTab(
                type: 'Files',
                onToggleSelection: _toggleFileSelection,
              ),
            ],
          ),

          // Floating Bottom Send Bar
          if (selectedFiles.isNotEmpty)
            Positioned(
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
              child: _buildFloatingSendBar(context, isDark, selectedFiles.length),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingSendBar(BuildContext context, bool isDark, int selectedCount) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '$selectedCount',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Selected',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RadarScanScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
            ),
            child: Text(
              'Send',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
