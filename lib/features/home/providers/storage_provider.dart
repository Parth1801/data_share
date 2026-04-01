import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageInfo {
  final double totalSpace; // in GB
  final double freeSpace;  // in GB
  final double usedSpace;  // in GB
  final double usagePercentage; // 0.0 to 1.0

  StorageInfo({
    required this.totalSpace,
    required this.freeSpace,
    required this.usedSpace,
    required this.usagePercentage,
  });
}

final storageProvider = FutureProvider<StorageInfo>((ref) async {
  final totalMB = await DiskSpace.getTotalDiskSpace ?? 0.0;
  final freeMB = await DiskSpace.getFreeDiskSpace ?? 0.0;

  final totalGB = totalMB / 1024.0;
  final freeGB = freeMB / 1024.0;
  final usedGB = totalGB - freeGB;
  final usagePercentage = totalGB > 0 ? usedGB / totalGB : 0.0;

  return StorageInfo(
    totalSpace: totalGB,
    freeSpace: freeGB,
    usedSpace: usedGB,
    usagePercentage: usagePercentage,
  );
});
