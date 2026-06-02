import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:untitled/l10n/app_localizations.dart';
import 'package:untitled/providers/auth_provider.dart' as app_auth;
import 'package:untitled/providers/theme_provider.dart';
import 'package:untitled/providers/notification_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/notification_service.dart';
import 'package:untitled/screens/PostDetailPage.dart';



class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final _postController = TextEditingController();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _showPostCreation = false;
  bool _isSearching = false;
  String? _selectedImageUrl;
  File? _selectedImageFile;
  String _searchQuery = '';
  StreamSubscription<QuerySnapshot>? _statusListener;

  @override
  void initState() {
    super.initState();
    _setupForumStatusListener();
  }

  @override
  void dispose() {
    _statusListener?.cancel();
    super.dispose();
  }

  // Cloudinary API Details
  final String cloudinaryUrl = "https://api.cloudinary.com/v1_1/ds8esjc0y/image/upload";
  final String uploadPreset = "flutter_upload";

  void _setupForumStatusListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('Setting up forum status listener for user: ${currentUser.uid}'); // Debug log
      _statusListener = FirebaseFirestore.instance
          .collection('forums')
          .where('authorId', isEqualTo: currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        print('Received snapshot with ${snapshot.docChanges.length} changes'); // Debug log
        for (var change in snapshot.docChanges) {
          print('Change type: ${change.type}'); // Debug log
          if (change.type == DocumentChangeType.modified) {
            final forumData = change.doc.data() as Map<String, dynamic>;
            final currentStatus = forumData['status'] as String?;
            print('Forum post modified - Status: $currentStatus'); // Debug log
            
            // Check if status is Approved or Rejected
            if (currentStatus != null && 
                (currentStatus == 'Approved' || currentStatus == 'Rejected')) {
              print('Sending notification for status: $currentStatus'); // Debug log
              NotificationService().sendForumStatusNotification(
                userId: currentUser.uid,
                forumTitle: forumData['title'] ?? 'Untitled',
                status: currentStatus,
                forumId: change.doc.id,
              );
            }
          }
        }
      });
    }
  }

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
  Future<String?> _getPhotoURL(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['photoURL'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      setState(() => _isLoading = true);

      var request = http.MultipartRequest("POST", Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      setState(() => _isLoading = false);
      return jsonResponse['secure_url']; // Returns the uploaded image URL
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: ${e.toString()}')),
      );
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // Limit max width for optimization
        maxHeight: 1080, // Limit max height for optimization
        imageQuality: 85, // Slightly compress image for better upload speed
      );

      if (image != null) {
        _selectedImageFile = File(image.path);

        // Upload to Cloudinary
        final imageUrl = await _uploadImageToCloudinary(_selectedImageFile!);

        if (imageUrl != null) {
          setState(() {
            _selectedImageUrl = imageUrl;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: ${e.toString()}')),
      );
    }
  }

  Future<void> _createPost(dynamic docRef) async {
    final title = _titleController.text.trim();
    final content = _postController.text.trim();

    print('Attempting to create post:');
    print('Title: $title');
    print('Content: $content');
    print('Image URL: $_selectedImageUrl');

    if (title.isEmpty || content.isEmpty) {
      print('Title or content is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and content')),
      );
      return;
    }

    setState(() {
      print('Setting loading state to true');
      _isLoading = true;
    });

    try {
      final user = context.read<app_auth.AuthProvider>().user;
      if (user == null) {
        print('User is not authenticated');
        throw Exception('User not authenticated');
      }

      // Get username from Firestore
      String? username = await _getUserName(user.uid);
      String? photoURL = await _getPhotoURL(user.uid);

      print('Creating post in Firestore');
      // Create the post first
      final docRef = await FirebaseFirestore.instance.collection('forums').add({
        'title': title,
        'content': content,
        'authorId': user.uid,
        'authorName': username ?? 'Anonymous',
        'authorAvatar': photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'comments': 0,
        'status': 'Pending',
        'imageUrl': _selectedImageUrl ?? '',
        'likedBy': [],
      });

      print('Post created successfully with ID: ${docRef.id}');
      _titleController.clear();
      _postController.clear();
      setState(() {
        _showPostCreation = false;
        _selectedImageUrl = null;
        _selectedImageFile = null;
      });

      // Check for mentions in the content
      final mentions = RegExp(r'@([\w\s]+)(?=\s|$)').allMatches(content);
      final notificationService = NotificationService();

      for (final mention in mentions) {
        final username = mention.group(1);
        if (username != null) {
          // Find the mentioned user
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            final mentionedUserId = userQuery.docs.first.id;
            if (mentionedUserId != user.uid) {
              // Send notification to mentioned user
              await notificationService.sendForumNotification(
                userId: mentionedUserId,
                title: 'New Mention',
                body: '$username mentioned you in a post: "$title"',
                type: 'mention',
                postId: docRef.id,
              );
            }
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created and pending approval!')),
      );
    } catch (e) {
      print('Error creating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: ${e.toString()}')),
      );
    } finally {
      setState(() {
        print('Setting loading state to false');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLike(String postId, Map<String, dynamic> post) async {
    try {
      final user = context.read<app_auth.AuthProvider>().user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to sign in to like posts')),
        );
        return;
      }

      // Get a reference to the post
      final postRef = FirebaseFirestore.instance.collection('forums').doc(postId);

      try {
        // Get the current user's username
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final username = userDoc.data()?['username'] ?? 'Someone';

        // Check if the post has a likedBy field
        List<dynamic> likedBy = post['likedBy'] ?? [];

        // Convert to List<String> if it exists
        List<String> likedByIds = likedBy.map((e) => e.toString()).toList();

        // Check if user already liked this post
        bool userLiked = likedByIds.contains(user.uid);

        if (userLiked) {
          // User already liked this post, so unlike it (remove from list and decrement count)
          await postRef.update({
            'upvotes': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([user.uid]),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post unliked'),
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          // User has not liked this post yet, so like it (add to list and increment count)
          await postRef.update({
            'upvotes': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([user.uid]),
          });

          // Send notification to post author if it's not their own post
          if (post['authorId'] != user.uid) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': post['authorId'],
              'title': 'New Like',
              'body': '@$username liked your post "${post['title']}"',
              'type': 'like',
              'postId': postId,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post liked!'),
              duration: Duration(seconds: 1),
            ),
          );
        }

      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          // Permission issue - show helpful message to the user
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cannot Like Post'),
              content: const Text(
                'Your current permissions do not allow liking posts. Please ask an administrator to update the Firestore rules to allow updates to the "upvotes" and "likedBy" fields by regular users.\n\n'
                'Suggested rule to add:\n\n'
                'allow update: if request.auth != null &&\n'
                '  request.resource.data.diff(resource.data).affectedKeys().hasOnly([\'upvotes\', \'likedBy\']) &&\n'
                '  (request.resource.data.upvotes == resource.data.upvotes + 1 ||\n'
                '   request.resource.data.upvotes == resource.data.upvotes - 1);'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error liking post: ${e.toString()}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing like: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final user = context.watch<app_auth.AuthProvider>().user;


    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search posts...',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              )
            : Text(
                AppLocalizations.of(context).translate('community'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              if (context.watch<NotificationProvider>().hasUnread)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 2, top: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Create post compact bar
          if (!_showPostCreation)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  setState(() {
                    _showPostCreation = true;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: user != null
                      ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
                      : null,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const CircleAvatar(
                        radius: 20,
                        child: Icon(Icons.person),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final username = data['username'] ?? 'A';
                    final photoUrl = data['photoURL'] ?? '';

                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(30),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'A',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : null,
                    );
                  },
                ),

                const SizedBox(width: 12),
                Expanded(
                        child: Text(
                          AppLocalizations.of(context).translate('what_is_on_your_mind'),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.photo_library_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Post Creation Card
          if (_showPostCreation)
            Card(
              // margin: const EdgeInsets.all(12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            FutureBuilder<DocumentSnapshot>(
                              future: user != null
                                  ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
                                  : null,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                }

                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return const CircleAvatar(
                                    radius: 20,
                                    child: Icon(Icons.person),
                                  );
                                }

                                final data = snapshot.data!.data() as Map<String, dynamic>;
                                final username = data['username'] ?? 'A';
                                final photoUrl = data['photoURL'] ?? '';

                                return CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(30),
                                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  child: photoUrl.isEmpty
                                      ? Text(
                                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            if (user != null)
                              FutureBuilder<String?>(
                                future: _getUserName(user.uid),
                                builder: (context, snapshot) {
                                  final username = snapshot.data;
                                  return Text(
                                    username != null && username.isNotEmpty ? username : '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showPostCreation = false;
                              _titleController.clear();
                              _postController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('what_is_this_discussion'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.grey[500],
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Post Creation Card content area
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                    controller: _postController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).translate('what_is_on_your_mind'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.white60 : Colors.grey[500],
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.3,
                          ),
                          maxLines: 6,
                          minLines: 3,
                        ),
                        if (_selectedImageUrl != null) ...[
                          const SizedBox(height: 16),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _selectedImageUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImageUrl = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _mediaButton(
                                icon: Icons.photo,
                                label: AppLocalizations.of(context).translate('photo'),
                                color: Colors.green,
                                onTap: _pickImage,
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: _titleController.text.trim().isNotEmpty && _postController.text.trim().isNotEmpty
                              ? const Color(0xFF4080FF)
                              : isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              if (_isLoading) {
                                return;
                              }
                              if (_titleController.text.trim().isEmpty || _postController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill in both title and content')),
                                );
                                return;
                              }
                              _createPost(null);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context).translate('post'),
                                          style: TextStyle(
                                            color: _titleController.text.trim().isNotEmpty && _postController.text.trim().isNotEmpty
                                                ? Colors.white
                                                : isDarkMode ? Colors.grey[600] : Colors.grey[500],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_titleController.text.trim().isNotEmpty && _postController.text.trim().isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.send,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
              ],
            ),
          ),

          // Posts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('forums')
                  .where('status', isEqualTo: 'Approved')
                  .orderBy('createdAt', descending: true)
                  .orderBy(FieldPath.documentId, descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // Show a more user-friendly error message for permission errors
                  if (snapshot.error.toString().contains('permission-denied')) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: isDarkMode ? Colors.white30 : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to access posts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'You may need to sign in or request access to view this content.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }

                var forums = snapshot.data?.docs ?? [];
                
                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  forums = forums.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] as String).toLowerCase();
                    final content = (data['content'] as String).toLowerCase();
                    final searchLower = _searchQuery.toLowerCase();
                    
                    return title.contains(searchLower) || content.contains(searchLower);
                  }).toList();
                }

                if (forums.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: isDarkMode ? Colors.white30 : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No posts yet. Be the first to share!',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: forums.length,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (context, index) {
                    final post = forums[index].data() as Map<String, dynamic>;
                    final postId = forums[index].id;

                    return ForumCard(
                      post: post,
                      postId: postId,
                      onLike: () {
                        _handleLike(postId, post);
                      },
                      onShare: () {
                        // Implement share functionality
                      },
                      onMoreOptions: () {
                        // Show post options
                        final isUserPost = post['authorId'] == context.read<app_auth.AuthProvider>().user?.uid;
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                          children: [
                              if (isUserPost)
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit Post'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showEditPostDialog(context, postId, post);
                                  },
                                ),
                              if (isUserPost)
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.red),
                                  title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showDeleteConfirmation(context, postId, post);
                                  },
                                ),
                              if (!isUserPost)
                                ListTile(
                                  leading: const Icon(Icons.report),
                                  title: const Text('Report Post'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    // Implement report
                                  },
                                ),
                            //   ListTile(
                            //     leading: const Icon(Icons.share),
                            //     title: const Text('Share Post'),
                            //     onTap: () {
                            //       Navigator.pop(context);
                            //       // Implement share
                            //     },
                            // ),
                          ],
                        ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _showPostCreation
          ? null
          : FloatingActionButton(
          onPressed: () {
            setState(() {
          _showPostCreation = true;
            });
          },
          mini: true,
          backgroundColor: const Color.fromARGB(255, 255, 193, 7),
          child: const Icon(Icons.add, color: Colors.white),
        ),
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
                      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPostDialog(BuildContext context, String postId, Map<String, dynamic> post) {
    final TextEditingController titleController = TextEditingController(text: post['title']);
    final TextEditingController contentController = TextEditingController(text: post['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('edit_post')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter post title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Update your post content...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and content cannot be empty')),
                );
                return;
              }

              _updatePost(postId, titleController.text.trim(), contentController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePost(String postId, String newTitle, String newContent) async {
    try {
      await FirebaseFirestore.instance.collection('forums').doc(postId).update({
        'title': newTitle,
        'content': newContent,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating post: ${e.toString()}')),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, String postId, Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              _deletePost(postId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('forums').doc(postId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting post: ${e.toString()}')),
      );
    }
  }
}

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
    final isUserPost = post['authorId'] == context.read<app_auth.AuthProvider>().user?.uid;

    // Check if current user has liked this post
    final user = context.read<app_auth.AuthProvider>().user;
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
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
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
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
