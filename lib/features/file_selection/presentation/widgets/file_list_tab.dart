import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FileListTab extends StatelessWidget {
  final String type;
  final VoidCallback onToggleSelection;
  final bool isGrid;

  const FileListTab({
    super.key,
    required this.type,
    required this.onToggleSelection,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return isGrid ? _buildGridView(context) : _buildListView(context);
  }

  Widget _buildListView(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h), // Space for floating bar
      itemCount: 15,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Container(
            width: 45.w,
            height: 45.w,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(_getIconForType(), color: Theme.of(context).primaryColor),
          ),
          title: Text(
            'Sample ${type.substring(0, type.length > 1 ? type.length - 1 : 1)} ${index + 1}',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${(index + 1) * 2.5} MB',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
          trailing: IconButton(
            icon: Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
            onPressed: onToggleSelection,
          ),
          onTap: onToggleSelection,
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.only(left: 10.w, right: 10.w, top: 10.h, bottom: 100.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
      ),
      itemCount: 20,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: onToggleSelection,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    type == 'Photos' ? Icons.image : Icons.video_library,
                    size: 40.sp,
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                  ),
                ),
                Positioned(
                  top: 5.h,
                  right: 5.w,
                  child: Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForType() {
    switch (type) {
      case 'Apps':
        return Icons.android;
      case 'Music':
        return Icons.music_note;
      case 'Files':
        return Icons.folder;
      case 'History':
        return Icons.history;
      default:
        return Icons.insert_drive_file;
    }
  }
}
