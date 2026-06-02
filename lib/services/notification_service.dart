import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const AndroidNotificationChannel _forumNotificationChannel = AndroidNotificationChannel(
  'forum_channel',
  'Forum Notifications',
  description: 'Notifications for forum activities',
  importance: Importance.high,
);

@pragma('vm:entry-point')
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
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

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        _handleNotificationTap(details);
      },
    );

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_forumNotificationChannel);
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle notification taps when app is resumed or launched from terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTapFromMessage(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTapFromMessage(initialMessage);
    }

    // Get FCM token
    String? token = await _fcm.getToken();
    await _saveTokenToDatabase(token);

    // Save token after sign-in if auth happens after app start
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final currentToken = await _fcm.getToken();
        await _saveTokenToDatabase(currentToken);
      }
    });
  
    // Listen to token refresh
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  Future<void> _saveTokenToDatabase(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      _forumNotificationChannel.id,
      _forumNotificationChannel.name,
      channelDescription: _forumNotificationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'New Notification',
      message.notification?.body,
      notificationDetails,
      payload: message.data['type'] ?? message.messageId ?? '',
    );
  }

  void _handleNotificationTap(NotificationResponse details) {
    final payload = details.payload;
    if (payload != null && payload.isNotEmpty) {
      _routeFromPayload(payload);
    }
  }

  void _handleNotificationTapFromMessage(RemoteMessage message) {
    final payload = message.data['type'] ?? message.messageId ?? '';
    if (payload.isNotEmpty) {
      _routeFromPayload(payload);
    }
  }

  void _routeFromPayload(String payload) {
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
      case 'forum_status':
        // Navigate to forum status page or notification center
        break;
      default:
        // Unknown payload type
        break;
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

      // Show local notification for current session
      final androidDetails = AndroidNotificationDetails(
        _forumNotificationChannel.id,
        _forumNotificationChannel.name,
        channelDescription: _forumNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Forum Status Update',
        message,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'forum_status',
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
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_forumNotificationChannel);
  }

  final androidDetails = AndroidNotificationDetails(
    _forumNotificationChannel.id,
    _forumNotificationChannel.name,
    channelDescription: _forumNotificationChannel.description,
    importance: Importance.high,
    priority: Priority.high,
  );

  final notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: const DarwinNotificationDetails(),
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    message.notification?.title ?? 'New Notification',
    message.notification?.body,
    notificationDetails,
    payload: message.data['type'] ?? message.messageId ?? '',
  );
}


