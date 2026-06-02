import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    // Request permission for notifications
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        _handleNotificationTap(details);
      },
    );

    // Get FCM token
    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToDatabase(token);
    }

    // Listen to token refresh
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'forum_channel',
      'Forum Notifications',
      channelDescription: 'Notifications for forum activities',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      message.notification?.title ?? 'New Notification',
      message.notification?.body,
      notificationDetails,
      payload: message.data['type'] ?? '',
    );
  }

  void _handleNotificationTap(NotificationResponse details) {
    // Handle notification tap based on the payload
    final payload = details.payload;
    if (payload != null) {
      switch (payload) {
        case 'like':
          // Navigate to the post
          break;
        case 'comment':
          // Navigate to the comments section
          break;
        case 'mention':
          // Navigate to the mention
          break;
      }
    }
  }

  Future<void> sendForumStatusNotification({
    required String userId,
    required String forumTitle,
    required String status,
    required String forumId,
  }) async {
    try {
      // Create notification message based on status
      String message = 'Your forum post "$forumTitle" has been ${status.toLowerCase()}';
      
      // Save notification to Firestore
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Forum Status Update',
        'body': message,
        'type': 'forum_status',
        'forumId': forumId,
        'status': status,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Show local notification
      await _localNotifications.show(
        DateTime.now().millisecond,
        'Forum Status Update',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'forum_status',
            'Forum Status Updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      print('Error sending forum status notification: $e');
    }
  }

  Future<void> sendForumNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? postId,
    String? status,
    String? forumId,
  }) async {
    try {
      // Save notification to Firestore with proper structure according to rules
      final notification = {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add optional fields if they exist
      if (postId != null) notification['postId'] = postId;
      if (status != null) notification['status'] = status;
      if (forumId != null) notification['forumId'] = forumId;

      await _firestore.collection('notifications').add(notification);
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  print('Handling a background message: ${message.messageId}');
}


