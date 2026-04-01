class HistoryItem {
  final String id;
  final String name;
  final String path;
  final double sizeMB;
  final String type;
  final DateTime timestamp;
  final bool isSent;

  HistoryItem({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeMB,
    required this.type,
    required this.timestamp,
    required this.isSent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'sizeMB': sizeMB,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'isSent': isSent,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'],
    name: json['name'],
    path: json['path'],
    sizeMB: (json['sizeMB'] as num).toDouble(),
    type: json['type'],
    timestamp: DateTime.parse(json['timestamp']),
    isSent: json['isSent'],
  );
}
