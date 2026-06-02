import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NotificationProvider with ChangeNotifier {
  bool _hasUnread = false;
  bool get hasUnread => _hasUnread;

  StreamSubscription<QuerySnapshot>? _subscription;

  NotificationProvider() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _initNotificationListener();
      } else {
        _subscription?.cancel();
        _hasUnread = false;
        notifyListeners();
      }
    });
    _initNotificationListener();
  }

  void _initNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _subscription?.cancel();
      _subscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        final hasUnread = snapshot.docs.isNotEmpty;
        if (hasUnread != _hasUnread) {
          _hasUnread = hasUnread;
          notifyListeners();
        }
      });
    }
  }

  void updateAuthState() {
    _initNotificationListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
