import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/PostDetailPage.dart';

class ForumCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String postId;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onMoreOptions;

  const ForumCard({
    super.key,
    required this.post,
    required this.postId,
    required this.onLike,
    required this.onShare,
    required this.onMoreOptions,
  });

  Future<String?> _getUserName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['username'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final hasImage = post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty;
    final theme = Theme.of(context);
    final isUserPost = post['authorId'] == context.read<AuthProvider>().user?.uid;

    // Check if current user has liked this post
    final user = context.read<AuthProvider>().user;
    final List<dynamic> likedBy = post['likedBy'] ?? [];
    final bool hasUserLiked = user != null && likedBy.contains(user.uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(
                post: post,
                postId: postId,
                onLike: (String id, Map<String, dynamic> updatedPost) => onLike(),
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info and timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: post['authorAvatar'] != null && post['authorAvatar'].toString().isNotEmpty
                        ? NetworkImage(post['authorAvatar'])
                        : null,
                    backgroundColor: post['authorAvatar'] == null || post['authorAvatar'].toString().isEmpty
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : null,
                    child: post['authorAvatar'] == null || post['authorAvatar'].toString().isEmpty
                        ? Text(
                            post['authorName'] != null && post['authorName'].toString().isNotEmpty
                                ? post['authorName'].toString()[0].toUpperCase()
                                : 'A',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            post['authorName'] != null && post['authorName'].toString().isNotEmpty
                                ? Text(
                                    post['authorName'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  )
                                : FutureBuilder<String?>(
                                    future: _getUserName(post['authorId']),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const SizedBox(
                                          width: 50,
                                          height: 15,
                                          child: LinearProgressIndicator(),
                                        );
                                      }
                                      final username = snapshot.data ?? 'Unknown';
                                      return Text(
                                        username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      );
                                    },
                                  ),
                            if (isUserPost) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _formatTimestamp(post['createdAt']),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_horiz,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                    onPressed: onMoreOptions,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                post['title'] ?? '',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Image if exists
            if (hasImage)
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  post['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
                    );
                  },
                ),
              ),

            // Engagement stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    hasUserLiked ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: hasUserLiked ? Colors.red : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post['upvotes'] ?? 0}',
                    style: TextStyle(
                      color: hasUserLiked ? Colors.red : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post['comments'] ?? 0}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Add divider
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            ),
          ],
        ),
      ),
    );
  }
}