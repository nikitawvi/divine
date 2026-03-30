// ABOUTME: DTO for unread notifications count response.
// ABOUTME: Keeps read-state contract explicit at API boundary.

class ApiUnreadCountResponse {
  const ApiUnreadCountResponse({required this.unreadCount});

  final int unreadCount;
}
