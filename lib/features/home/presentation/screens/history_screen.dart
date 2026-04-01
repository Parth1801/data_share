import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Transfer History'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: theme.brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearConfirmation(context, ref),
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80.sp,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No transfers yet',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: _getColorForType(item.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      _getIconForType(item.type),
                      color: _getColorForType(item.type),
                      size: 24.sp,
                    ),
                  ),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '${item.sizeMB.toStringAsFixed(2)} MB • ${item.isSent ? 'Sent' : 'Received'} • ${_formatDate(item.timestamp)}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                  onTap: () async {
                    if (item.path.isNotEmpty) {
                      if (item.path.toLowerCase().endsWith('.apk') || item.type.toLowerCase() == 'app') {
                        final status = await Permission.requestInstallPackages.request();
                        if (status.isGranted) {
                          await OpenFilex.open(item.path);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Installation permission denied.')),
                          );
                        }
                      } else {
                        await OpenFilex.open(item.path);
                      }
                    }
                  },
                  trailing: Icon(
                    item.isSent ? Icons.call_made : Icons.call_received,
                    size: 18.sp,
                    color: item.isSent ? Colors.blue : Colors.green,
                  ),
                );
              },
            ),
    );
  }

  void _showClearConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all transfer history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
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
      case 'app':
        return Icons.android;
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
      case 'app':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
