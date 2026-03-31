// ABOUTME: HTTP client for Divine Relay notifications REST API with NIP-98 authentication
// ABOUTME: Provides server-side filtered notifications, pagination, and mark-as-read functionality

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Notification from the Divine Relay API
class RelayNotification {
  const RelayNotification({
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

  factory RelayNotification.fromJson(Map<String, dynamic> json) {
    return RelayNotification(
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
  final String
  notificationType; // "reaction", "reply", "repost", "follow", "zap"
  final DateTime createdAt;
  final bool read;
  final String? content;

  /// Stable key for local deduplication and filtering.
  /// Falls back to sourceEventId if API doesn't provide an id field.
  /// Note: Use [id] (not this) for API write operations like markAsRead.
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

  RelayNotification copyWith({
    String? id,
    String? sourcePubkey,
    String? sourceEventId,
    int? sourceKind,
    String? referencedEventId,
    String? notificationType,
    DateTime? createdAt,
    bool? read,
    String? content,
  }) {
    return RelayNotification(
      id: id ?? this.id,
      sourcePubkey: sourcePubkey ?? this.sourcePubkey,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      sourceKind: sourceKind ?? this.sourceKind,
      referencedEventId: referencedEventId ?? this.referencedEventId,
      notificationType: notificationType ?? this.notificationType,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      content: content ?? this.content,
    );
  }

  @override
  String toString() =>
      'RelayNotification(id: $id, type: $notificationType, from: $sourcePubkey)';
}

/// Response from GET /api/users/{pubkey}/notifications
class NotificationsResponse {
  const NotificationsResponse({
    required this.notifications,
    required this.unreadCount,
    this.nextCursor,
    this.hasMore = false,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final notificationsData = json['notifications'] as List<dynamic>? ?? [];

    return NotificationsResponse(
      notifications: notificationsData
          .map((n) => RelayNotification.fromJson(n as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
      nextCursor: json['next_cursor']?.toString(),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  final List<RelayNotification> notifications;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;

  static const empty = NotificationsResponse(notifications: [], unreadCount: 0);
}

/// Response from POST /api/users/{pubkey}/notifications/read
class MarkReadResponse {
  const MarkReadResponse({
    required this.success,
    this.markedCount = 0,
    this.error,
  });

  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkReadResponse(
      success: json['success'] as bool? ?? false,
      markedCount: json['marked_count'] as int? ?? 0,
      error: json['error']?.toString(),
    );
  }

  final bool success;
  final int markedCount;
  final String? error;
}

/// Service for interacting with Divine Relay notifications REST API
///
/// Uses NIP-98 HTTP authentication for all requests.
/// Provides server-side filtering, pagination, and read state management.
class RelayNotificationApiService {
  RelayNotificationApiService({
    required String? baseUrl,
    required Nip98AuthService nip98AuthService,
    http.Client? httpClient,
    FunnelcakeApiClient? apiClient,
  }) : _apiClient =
           apiClient ??
           FunnelcakeApiClient(
             baseUrl: baseUrl ?? '',
             httpClient: httpClient,
             authorizationHeaderBuilder:
                 ({
                   required String url,
                   required String method,
                   String? payload,
                 }) async {
                   final nip98Method = method.toUpperCase() == 'POST'
                       ? HttpMethod.post
                       : HttpMethod.get;
                   final authToken = await nip98AuthService.createAuthToken(
                     url: url,
                     method: nip98Method,
                     payload: payload,
                   );
                   return authToken?.authorizationHeader;
                 },
           );

  final FunnelcakeApiClient _apiClient;

  /// Whether the API is available (has a configured base URL)
  bool get isAvailable => _apiClient.isAvailable;

  /// Fetch notifications for a user
  ///
  /// [pubkey] - Hex public key of the user
  /// [types] - Optional list of notification types to filter ("reaction", "reply", "repost", "follow", "zap")
  /// [unreadOnly] - If true, only return unread notifications
  /// [limit] - Maximum number of notifications to return (default 50)
  /// [before] - Cursor for pagination (get notifications before this cursor)
  Future<NotificationsResponse> getNotifications({
    required String pubkey,
    List<String>? types,
    bool unreadOnly = false,
    int limit = 50,
    String? before,
  }) async {
    if (!isAvailable) {
      Log.warning(
        'Relay Notifications API not available (no base URL configured)',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return NotificationsResponse.empty;
    }

    if (pubkey.isEmpty) {
      Log.warning(
        'Cannot fetch notifications without pubkey',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return NotificationsResponse.empty;
    }

    try {
      final apiResponse = await _apiClient.getNotifications(
        pubkey: pubkey,
        types: types ?? const [],
        unreadOnly: unreadOnly,
        limit: limit,
        before: before,
      );
      final result = _notificationsResponseFromApi(apiResponse);

      final typeBreakdown = <String, int>{};
      for (final n in result.notifications) {
        typeBreakdown[n.notificationType] =
            (typeBreakdown[n.notificationType] ?? 0) + 1;
      }
      Log.info(
        'Received ${result.notifications.length} notifications, '
        'unread: ${result.unreadCount}, hasMore: ${result.hasMore}, '
        'types: $typeBreakdown',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );

      return result;
    } catch (e) {
      Log.error(
        'Error fetching notifications: $e',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return NotificationsResponse.empty;
    }
  }

  /// Mark notifications as read
  ///
  /// [pubkey] - Hex public key of the user
  /// [notificationIds] - Optional list of specific notification IDs to mark as read.
  ///                     If null or empty, marks ALL notifications as read.
  Future<MarkReadResponse> markAsRead({
    required String pubkey,
    List<String>? notificationIds,
  }) async {
    if (!isAvailable) {
      Log.warning(
        'Relay Notifications API not available (no base URL configured)',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return const MarkReadResponse(success: false, error: 'API not available');
    }

    if (pubkey.isEmpty) {
      Log.warning(
        'Cannot mark notifications without pubkey',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return const MarkReadResponse(success: false, error: 'Missing pubkey');
    }

    try {
      Log.info(
        'Marking notifications as read: ${notificationIds?.length ?? "all"}',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );

      final apiResponse = await _apiClient.markNotificationsRead(
        pubkey: pubkey,
        notificationIds: notificationIds ?? const [],
      );
      final result = _markReadResponseFromApi(apiResponse);

      Log.info(
        'Marked ${result.markedCount} notifications as read',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );

      return result;
    } catch (e) {
      Log.error(
        'Error marking notifications as read: $e',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return MarkReadResponse(success: false, error: e.toString());
    }
  }

  /// Get unread notification count
  ///
  /// This is a convenience method that fetches just the unread count
  /// without loading all notification data.
  Future<int> getUnreadCount({required String pubkey}) async {
    try {
      final response = await _apiClient.getUnreadNotificationsCount(
        pubkey: pubkey,
      );
      return response.unreadCount;
    } catch (e) {
      Log.error(
        'Error fetching unread count: $e',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return 0;
    }
  }

  /// Dispose of resources
  void dispose() {
    _apiClient.dispose();
  }
}

RelayNotification _relayNotificationFromApi(ApiNotification source) {
  return RelayNotification(
    id: source.id,
    sourcePubkey: source.sourcePubkey,
    sourceEventId: source.sourceEventId,
    sourceKind: source.sourceKind,
    notificationType: source.notificationType,
    createdAt: source.createdAt,
    read: source.read,
    referencedEventId: source.referencedEventId,
    content: source.content,
  );
}

NotificationsResponse _notificationsResponseFromApi(
  ApiNotificationsResponse source,
) {
  return NotificationsResponse(
    notifications: source.notifications.map(_relayNotificationFromApi).toList(),
    unreadCount: source.unreadCount,
    nextCursor: source.nextCursor,
    hasMore: source.hasMore,
  );
}

MarkReadResponse _markReadResponseFromApi(ApiMarkReadResponse source) {
  return MarkReadResponse(
    success: source.success,
    markedCount: source.markedCount,
    error: source.error,
  );
}
