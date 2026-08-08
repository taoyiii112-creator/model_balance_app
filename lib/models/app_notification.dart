/// 应用内消息中心的一条消息。
///
/// 由应用事件（低余额、发现新版本等）生成，落库展示；
/// [dedupeKey] 用于同一事件在短期内只产生一条（例如
/// `low_balance:deepseek-main:2026-08-09`）。
class AppNotification {
  AppNotification({
    this.id,
    required this.type,
    required this.title,
    required this.body,
    DateTime? createdAt,
    this.read = false,
    this.dedupeKey,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 数据库自增 id，未落库时为 null。
  final int? id;

  /// 类型：low_balance / update_available，用于图标与语义。
  final String type;

  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// 去重键（数据库唯一索引），可为空表示不去重。
  final String? dedupeKey;

  factory AppNotification.fromDbMap(Map<String, Object?> map) {
    return AppNotification(
      id: map['id'] as int,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      read: (map['read'] as int? ?? 0) == 1,
      dedupeKey: map['dedupe_key'] as String?,
    );
  }

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'type': type,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'read': read ? 1 : 0,
      'dedupe_key': dedupeKey,
    };
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      dedupeKey: dedupeKey,
    );
  }
}
