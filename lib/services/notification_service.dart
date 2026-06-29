// services/notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models/notification.dart';
import '../core/constants/app_constants.dart';
import '../core/auth/auth_session.dart';

class NotificationService {
  static const String baseUrl = AppConstants.apiBaseUrl;

  // Send notification
  static Future<Map<String, dynamic>> sendNotification({
    required String senderId,
    required String senderType, // "teacher" or "school_authority"
    required String tenantId,
    required String title,
    required String message,
    required String notificationType,
    required String recipientType,
    Map<String, dynamic>? recipientConfig,
    String priority = "normal",
    List<String> deliveryChannels = const ["in_app"],
    String? category,
    List<String>? tags,
  }) async {
    try {
      final url = '$baseUrl/api/v1/school_authority/notifications/send?sender_id=$senderId&sender_type=$senderType';
      
      final requestBody = {
        "tenant_id": tenantId,
        "title": title,
        "message": message,
        "notification_type": notificationType,
        "priority": priority,
        "recipient_type": recipientType,
        "recipient_config": recipientConfig,
        "delivery_channels": deliveryChannels,
        "category": category,
        "tags": tags,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...AuthSession.instance.headers(),
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  // Get notifications for user
  static Future<List<AppNotification>> getNotificationsForUser({
    required String userId,
    required String userType,
    required String tenantId,
    String? notificationType,
    String? status,
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      final queryParams = {
        'user_type': userType,
        'tenant_id': tenantId,
        'unread_only': unreadOnly.toString(),
        'limit': limit.toString(),
      };

      if (notificationType != null) {
        queryParams['notification_type'] = notificationType;
      }
      if (status != null) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$baseUrl/api/v1/school_authority/notifications/for-user/$userId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          ...AuthSession.instance.headers(),
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => AppNotification.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get notifications: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  // Mark notification as read
  static Future<void> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    try {
      final url = '$baseUrl/api/v1/school_authority/notifications/$notificationId/mark-read?user_id=$userId';

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          ...AuthSession.instance.headers(),
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Archive a notification (PATCH .../{id}/archive?user_id=)
  static Future<void> archive({
    required String notificationId,
    required String userId,
  }) =>
      _userScopedPatch(notificationId, 'archive', userId, 'archive');

  // Unarchive (PATCH .../{id}/unarchive?user_id=)
  static Future<void> unarchive({
    required String notificationId,
    required String userId,
  }) =>
      _userScopedPatch(notificationId, 'unarchive', userId, 'unarchive');

  static Future<void> _userScopedPatch(
      String notificationId, String action, String userId, String label) async {
    final uri = Uri.parse(
            '$baseUrl/api/v1/school_authority/notifications/$notificationId/$action')
        .replace(queryParameters: {'user_id': userId});
    final r = await http.patch(uri, headers: {
      ...AuthSession.instance.headers(),
      'Accept': 'application/json',
    });
    if (r.statusCode != 200) {
      throw Exception('Failed to $label notification: ${r.body}');
    }
  }

  // Delete a notification for a user (DELETE .../{id}/delete?user_id=)
  static Future<void> deleteNotification({
    required String notificationId,
    required String userId,
  }) async {
    final uri = Uri.parse(
            '$baseUrl/api/v1/school_authority/notifications/$notificationId/delete')
        .replace(queryParameters: {'user_id': userId});
    final r = await http.delete(uri, headers: {
      ...AuthSession.instance.headers(),
      'Accept': 'application/json',
    });
    if (r.statusCode != 200) {
      throw Exception('Failed to delete notification: ${r.body}');
    }
  }

  // Archived notifications for a user.
  static Future<List<AppNotification>> getArchived({
    required String userId,
    required String userType,
    required String tenantId,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
            '$baseUrl/api/v1/school_authority/notifications/archived/$userId')
        .replace(queryParameters: {
      'tenant_id': tenantId,
      'user_type': userType,
      'limit': limit.toString(),
    });
    final r = await http.get(uri, headers: {
      ...AuthSession.instance.headers(),
      'Accept': 'application/json',
    });
    if (r.statusCode == 200) {
      final List<dynamic> list = json.decode(r.body);
      return list.map((j) => AppNotification.fromJson(j)).toList();
    }
    throw Exception('Failed to load archived notifications: ${r.body}');
  }

  // Notifications a user has sent (staff outbox). Raw maps — different shape
  // (includes recipients + delivered_count).
  static Future<List<Map<String, dynamic>>> getSentBy({
    required String senderId,
    required String tenantId,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
            '$baseUrl/api/v1/school_authority/notifications/sent-by/$senderId')
        .replace(queryParameters: {'tenant_id': tenantId, 'limit': limit.toString()});
    final r = await http.get(uri, headers: {
      ...AuthSession.instance.headers(),
      'Accept': 'application/json',
    });
    if (r.statusCode == 200) {
      final List<dynamic> list = json.decode(r.body);
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to load sent notifications: ${r.body}');
  }
}
