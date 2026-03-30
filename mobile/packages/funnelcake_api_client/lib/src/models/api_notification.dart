// ABOUTME: DTO for notification items returned by Funnelcake notifications API.
// ABOUTME: Contains API-specific fields and parsing helpers.

class ApiNotification {
  const ApiNotification({
    required this.id,
    required this.sourcePubkey,
    required this.sourceEventId,
    required this.sourceKind,
    required this.notificationType,
    required this.createdAt,
    required this.read,
    this.referencedEventId,
    this.content,
  });

  factory ApiNotification.fromJson(Map<String, dynamic> json) {
    return ApiNotification(
      id: json['id']?.toString() ?? '',
      sourcePubkey: json['source_pubkey']?.toString() ?? '',
      sourceEventId: json['source_event_id']?.toString() ?? '',
      sourceKind: json['source_kind'] as int? ?? 0,
      referencedEventId: json['referenced_event_id']?.toString(),
      notificationType: json['notification_type']?.toString() ?? 'unknown',
      createdAt: _parseDateTime(json['created_at']),
      read: json['read'] as bool? ?? false,
      content: json['content']?.toString(),
    );
  }

  final String id;
  final String sourcePubkey;
  final String sourceEventId;
  final int sourceKind;
  final String? referencedEventId;
  final String notificationType;
  final DateTime createdAt;
  final bool read;
  final String? content;

  /// Stable key for local deduplication.
  String get dedupeKey => id.isNotEmpty ? id : sourceEventId;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
