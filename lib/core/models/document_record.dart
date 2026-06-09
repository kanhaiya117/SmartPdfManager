import 'dart:convert';
import 'dart:io';

class DocumentRecord {
  const DocumentRecord({
    required this.path,
    required this.name,
    required this.openedAt,
    this.isFavorite = false,
    this.size = 0,
  });

  final String path;
  final String name;
  final DateTime openedAt;
  final bool isFavorite;
  final int size;

  DocumentRecord copyWith({
    String? path,
    String? name,
    DateTime? openedAt,
    bool? isFavorite,
    int? size,
  }) {
    return DocumentRecord(
      path: path ?? this.path,
      name: name ?? this.name,
      openedAt: openedAt ?? this.openedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      size: size ?? this.size,
    );
  }

  Map<String, Object> toMap() => {
    'path': path,
    'name': name,
    'openedAt': openedAt.toIso8601String(),
    'isFavorite': isFavorite,
    'size': size,
  };

  factory DocumentRecord.fromMap(Map<String, dynamic> map) {
    return DocumentRecord(
      path: map['path'] as String,
      name: map['name'] as String,
      openedAt: DateTime.parse(map['openedAt'] as String),
      isFavorite: map['isFavorite'] as bool? ?? false,
      size: map['size'] as int? ?? 0,
    );
  }

  static String encodeList(List<DocumentRecord> items) =>
      jsonEncode(items.map((item) => item.toMap()).toList());

  static List<DocumentRecord> decodeList(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .map((item) => DocumentRecord.fromMap(item as Map<String, dynamic>))
          .where((item) => File(item.path).existsSync())
          .toList();
    } on FormatException {
      return const [];
    }
  }
}
