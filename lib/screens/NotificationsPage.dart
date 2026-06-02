import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/theme_provider.dart';
import 'package:untitled/screens/PostDetailPage.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = false;

  Future<void> _markAllAsRead(User user) async {
    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking notifications as read: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) async {
    if (notification['read'] == false) {
      // Mark notification as read
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notification['id'])
          .update({'read': true});
    }

    if (!mounted) return;

    // Navigate based on notification type
    switch (notification['type']) {
      case 'like':
      case 'comment':
      case 'mention':
      case 'reply':
        if (notification['postId'] != null) {
          final postDoc = await FirebaseFirestore.instance
              .collection('forums')
              .doc(notification['postId'])
              .get();
          
          if (!mounted) return;
          
          if (postDoc.exists) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  post: postDoc.data()!,
                  postId: postDoc.id,
                  onLike: (String postId, Map<String, dynamic> post) async {
                    // Handle like
                  },
                ),
              ),
            );
          }
        }
        break;
      case 'forum_status':
        if (notification['forumId'] != null) {
          final postDoc = await FirebaseFirestore.instance
              .collection('forums')
              .doc(notification['forumId'])
              .get();
          
          if (!mounted) return;
          
          if (postDoc.exists) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  post: postDoc.data()!,
                  postId: postDoc.id,
                  onLike: (String postId, Map<String, dynamic> post) async {
                    // Handle like
                  },
                ),
              ),
            );
          }
        }
        break;
    }
  }

  Widget _buildNotificationItem(BuildContext context, Map<String, dynamic> notification) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    IconData iconData;
    Color iconColor;
    switch (notification['type']) {
      case 'like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        iconData = Icons.comment;
        iconColor = Colors.blue;
        break;
      case 'mention':
        iconData = Icons.alternate_email;
        iconColor = Colors.green;
        break;
      case 'reply':
        iconData = Icons.reply;
        iconColor = Colors.orange;
        break;
      case 'forum_status':
        if (notification['status'] == 'Approved') {
          iconData = Icons.check_circle;
          iconColor = Colors.green;
        } else {
          iconData = Icons.cancel;
          iconColor = Colors.red;
        }
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return InkWell(
      onTap: () => _handleNotificationTap(context, notification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification['read'] == false
              ? (isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05))
              : null,
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? '',
                    style: TextStyle(
                      fontWeight: notification['read'] == false
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'] ?? '',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(notification['createdAt']),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => _markAllAsRead(user),
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              // Add the document ID to the notification data
              notification['id'] = notifications[index].id;
              return _buildNotificationItem(context, notification);
            },
          );
        },
      ),
    );
  }
}