import 'package:flutter/foundation.dart';

import 'enums.dart';

/// Lightweight recency record backing the Home screen (SPEC 7, 41).
@immutable
class RecentItem {
  const RecentItem({
    required this.kind,
    required this.targetId,
    required this.lastUsedAt,
  });

  final RecentItemKind kind;
  final String targetId;
  final DateTime lastUsedAt;

  String get key => '${kind.storageValue}:$targetId';

  Map<String, Object?> toRow() => {
        'kind': kind.storageValue,
        'target_id': targetId,
        'last_used_at': lastUsedAt.millisecondsSinceEpoch,
      };

  factory RecentItem.fromRow(Map<String, Object?> row) => RecentItem(
        kind: RecentItemKind.fromStorage(row['kind'] as String?),
        targetId: row['target_id']! as String,
        lastUsedAt:
            DateTime.fromMillisecondsSinceEpoch(row['last_used_at']! as int),
      );

  @override
  bool operator ==(Object other) => other is RecentItem && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
