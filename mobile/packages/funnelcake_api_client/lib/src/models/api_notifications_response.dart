// ABOUTME: DTO wrapper for paginated notifications API responses.
// ABOUTME: Includes notifications list and pagination/read metadata.

import 'package:funnelcake_api_client/src/models/api_notification.dart';

class ApiNotificationsResponse {
  const ApiNotificationsResponse({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
    this.nextCursor,
  });

  factory ApiNotificationsResponse.fromJson(Map<String, dynamic> json) {
    final notificationsJson = json['notifications'] as List<dynamic>? ?? [];
    final notifications = notificationsJson
        .whereType<Map<String, dynamic>>()
        .map(ApiNotification.fromJson)
        .toList();

    return ApiNotificationsResponse(
      notifications: notifications,
      unreadCount: _parseInt(json['unread_count']),
      nextCursor: json['next_cursor']?.toString(),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  factory ApiNotificationsResponse.empty() {
    return const ApiNotificationsResponse(
      notifications: [],
      unreadCount: 0,
      hasMore: false,
    );
  }

  final List<ApiNotification> notifications;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
