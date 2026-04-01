class PartialTransfer {
  final String id; // Use fileName + fileSize as unique key
  final String name;
  final int totalSize;
  final int receivedBytes;
  final String path;
  final DateTime updatedAt;

  PartialTransfer({
    required this.id,
    required this.name,
    required this.totalSize,
    required this.receivedBytes,
    required this.path,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'totalSize': totalSize,
      'receivedBytes': receivedBytes,
      'path': path,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PartialTransfer.fromJson(Map<String, dynamic> json) {
    return PartialTransfer(
      id: json['id'],
      name: json['name'],
      totalSize: json['totalSize'],
      receivedBytes: json['receivedBytes'],
      path: json['path'],
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  PartialTransfer copyWith({
    int? receivedBytes,
    DateTime? updatedAt,
  }) {
    return PartialTransfer(
      id: id,
      name: name,
      totalSize: totalSize,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      path: path,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
