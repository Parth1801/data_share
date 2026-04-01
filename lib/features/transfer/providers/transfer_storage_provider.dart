import 'package:datatransfer/features/transfer/models/partial_transfer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class TransferStorageService {
  static const String _boxName = 'partial_transfers';

  Future<void> savePartialTransfer(PartialTransfer transfer) async {
    final box = await Hive.openBox(_boxName);
    await box.put(transfer.id, transfer.toJson());
  }

  Future<PartialTransfer?> getPartialTransfer(String id) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(id);
    if (data == null) return null;
    return PartialTransfer.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> removePartialTransfer(String id) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(id);
  }

  Future<void> clearPartialTransfer(String name) async {
    final box = await Hive.openBox(_boxName);
    final keysToDelete = <dynamic>[];
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        if (map['name'] == name) {
          keysToDelete.add(key);
        }
      }
    }
    for (var key in keysToDelete) {
      await box.delete(key);
    }
  }

  Future<List<PartialTransfer>> getAllPartialTransfers() async {
    final box = await Hive.openBox(_boxName);
    return box.values.map((e) {
      return PartialTransfer.fromJson(Map<String, dynamic>.from(e));
    }).toList();
  }
}

final transferStorageProvider = Provider((ref) => TransferStorageService());
