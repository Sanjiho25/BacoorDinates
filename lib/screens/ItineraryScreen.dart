import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'CreateTripPage.dart';
import 'ItineraryDetailPage.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  Future<void> _deleteItinerary(String itineraryId) async {
    final localizations = AppLocalizations.of(context);
    try {
      await FirebaseFirestore.instance.collection('itineraries').doc(itineraryId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('itinerary_deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate('error_deleting_itinerary')}${e.toString()}')),
        );
      }
    }
  }

  bool _isItineraryFinished(Map<String, dynamic> itinerary) {
    try {
      final end = itinerary['endDate'];
      DateTime dt;
      if (end == null) return false;
      if (end is Timestamp) {
        dt = end.toDate();
      } else if (end is DateTime) {
        dt = end;
      } else {
        return false;
      }
  // consider the end date as inclusive until the end of that day
  final endOfDay = DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
  return endOfDay.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmDeleteItinerary(String itineraryId) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.translate('confirm_delete')),
        content: Text(localizations.translate('confirm_delete_itinerary')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.translate('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteItinerary(itineraryId);
    }
  }

  String _formatDateRange(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return '';
    final startDate = start.toDate();
    final endDate = end.toDate();

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final startStr = '${monthNames[startDate.month - 1]} ${startDate.day}';
    final endStr = '${monthNames[endDate.month - 1]} ${endDate.day}, ${endDate.year}';

    return '$startStr - $endStr';
  }

  Widget _buildItineraryCard(Map<String, dynamic> itinerary, String itineraryId, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItineraryDetailPage(itineraryId: itineraryId),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (itinerary['imageUrl'] != null && itinerary['imageUrl'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              itinerary['imageUrl'],
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itinerary['title'] ?? localizations.translate('untitled_trip'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                itinerary['destination'] ?? '',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDateRange(itinerary['startDate'], itinerary['endDate']),
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('itineraries')
                                        .doc(itineraryId)
                                        .collection('activities')
                                        .get(),
                                    builder: (context, snapshot) {
                                      final count = snapshot.data?.docs.length ?? 0;
                                      return Text(
                                        '$count ${localizations.translate('activities')}',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                      );
                                    },
                                  ),
                                  Row(
                                    children: [
                                      Builder(builder: (context) {
                                        final finished = _isItineraryFinished(itinerary);
                                        return Chip(
                                          label: Text(
                                            finished ? localizations.translate('finished') : localizations.translate('upcoming'),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          backgroundColor: finished ? Colors.green[50] : Colors.grey[100],
                                        );
                                      }),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _confirmDeleteItinerary(itineraryId),
                                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                        tooltip: localizations.translate('delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final user = context.watch<AuthProvider>().user;
    final localizations = AppLocalizations.of(context);
    // Use tabs: Upcoming / Ongoing and Finished
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.translate('my_itineraries'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        body: Center(child: Text(localizations.translate('please_sign_in'))),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.translate('my_itineraries'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: localizations.translate('upcoming')),
              Tab(text: localizations.translate('finished')),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('itineraries')
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

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(child: Text(localizations.translate('no_itineraries')));
            }

            final finished = <QueryDocumentSnapshot>[];
            final upcoming = <QueryDocumentSnapshot>[];
            for (var d in docs) {
              final m = d.data() as Map<String, dynamic>;
              if (_isItineraryFinished(m)) {
                finished.add(d);
              } else {
                upcoming.add(d);
              }
            }

            return TabBarView(
              children: [
                // Upcoming tab
                ListView.builder(
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) {
                    final it = upcoming[index].data() as Map<String, dynamic>;
                    final id = upcoming[index].id;
                    return _buildItineraryCard(it, id, context);
                  },
                ),
                // Finished tab
                ListView.builder(
                  itemCount: finished.length,
                  itemBuilder: (context, index) {
                    final it = finished[index].data() as Map<String, dynamic>;
                    final id = finished[index].id;
                    return _buildItineraryCard(it, id, context);
                  },
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color.fromARGB(255, 255, 193, 7),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTripPage()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
