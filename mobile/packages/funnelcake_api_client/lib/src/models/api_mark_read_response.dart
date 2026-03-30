// ABOUTME: DTO for mark-as-read operations in notifications API.
// ABOUTME: Encapsulates success flag and server counters.

class ApiMarkReadResponse {
  const ApiMarkReadResponse({
    required this.success,
    this.markedCount = 0,
    this.error,
  });

  factory ApiMarkReadResponse.fromJson(Map<String, dynamic> json) {
    return ApiMarkReadResponse(
      success: json['success'] as bool? ?? false,
      markedCount: _parseInt(json['marked_count']),
      error: json['error']?.toString(),
    );
  }

  final bool success;
  final int markedCount;
  final String? error;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
