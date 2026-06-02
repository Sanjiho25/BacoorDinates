import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';
import 'CreateActivityPage.dart';
import 'EditTripPage.dart';
import 'ExploreMapPage.dart';

class ItineraryDetailPage extends StatelessWidget {
  final String itineraryId;

  const ItineraryDetailPage({super.key, required this.itineraryId});

  Future<void> _editTrip(BuildContext context, Map<String, dynamic> currentData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTripPage(
          itineraryId: itineraryId,
          currentData: currentData,
        ),
      ),
    );

    if (result == true) {
      // Refresh the page after successful edit
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('trip_updated_successfully')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteActivity(BuildContext context, String activityId) async {
    try {
      await FirebaseFirestore.instance
          .collection('itineraries')
          .doc(itineraryId)
          .collection('activities')
          .doc(activityId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('activity_deleted')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('activity_delete_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteActivity(BuildContext context, String activityId, String title) async {
  final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
  title: Text(localizations.translate('confirm_delete')),
  content: Text(localizations.translate('confirm_delete_activity')),
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
      await _deleteActivity(context, activityId);
    }
  }

  bool _isActivityFinished(Map<String, dynamic> activity) {
    try {
      final datetime = activity['datetime'];
      if (datetime == null) return false;
      DateTime dt;
      if (datetime is Timestamp) {
        dt = datetime.toDate();
      } else if (datetime is DateTime) {
        dt = datetime;
      } else {
        return false;
      }
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDateRange(Timestamp? start, Timestamp? end, BuildContext context) {
    if (start == null || end == null) return '';
    final startDate = start.toDate();
    final endDate = end.toDate();
    final localizations = AppLocalizations.of(context);
    
    final monthNames = [
      localizations.translate('month_jan'),
      localizations.translate('month_feb'),
      localizations.translate('month_mar'),
      localizations.translate('month_apr'),
      localizations.translate('month_may'),
      localizations.translate('month_jun'),
      localizations.translate('month_jul'),
      localizations.translate('month_aug'),
      localizations.translate('month_sep'),
      localizations.translate('month_oct'),
      localizations.translate('month_nov'),
      localizations.translate('month_dec'),
    ];
    
    final s = '${monthNames[startDate.month - 1]} ${startDate.day}';
    final e = '${monthNames[endDate.month - 1]} ${endDate.day}, ${endDate.year}';
    return '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('itineraries').doc(itineraryId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(localizations.translate('itinerary_not_found')));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            data['imageUrl'] ?? '',
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['destination'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDateRange(data['startDate'], data['endDate'], context),
                                      style: const TextStyle(fontSize: 13, color: Colors.white70),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizations.translate('activities_title'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('itineraries')
                                    .doc(itineraryId)
                                    .collection('activities')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.docs.length ?? 0;
                                  return Text(
                                    '$count ${localizations.translate('activities_count')}',
                                    style: const TextStyle(color: Colors.grey),
                                  );
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('itineraries')
                                .doc(itineraryId)
                                .collection('activities')
                                .orderBy('datetime')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Text(localizations.translate('no_activities'));
                              }

                              final activities = snapshot.data!.docs;
                                                      return ListView.builder(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: activities.length,
                                                        itemBuilder: (context, index) {
                                                          final doc = activities[index];
                                                          final activity = doc.data() as Map<String, dynamic>;
                                                          final activityId = doc.id;
                                                          DateTime dateTime;
                                                          if (activity['datetime'] is Timestamp) {
                                                            dateTime = (activity['datetime'] as Timestamp).toDate();
                                                          } else if (activity['datetime'] is DateTime) {
                                                            dateTime = activity['datetime'] as DateTime;
                                                          } else {
                                                            dateTime = DateTime.now();
                                                          }
                                                          final time = TimeOfDay.fromDateTime(dateTime);
                                                          final finished = _isActivityFinished(activity);

                                                          return Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                                            child: Row(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                SizedBox(
                                                                  width: 70,
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text(
                                                                        time.format(context),
                                                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                                                      ),
                                                                      if (finished)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(top: 4),
                                                                          child: Text(
                                                                            localizations.translate('finished'),
                                                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: GestureDetector(
                                                                    onTap: () {
                                                                      final double lat = double.tryParse('${activity['lat']}') ?? 0.0;
                                                                      final double lng = double.tryParse('${activity['lng']}') ?? 0.0;
                                                                      
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder: (context) => ExploreMapPage(
                                                                            placeLat: lat,
                                                                            placeLng: lng,
                                                                            placeTitle: activity['title'] ?? '',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                    child: Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(12),
                                                                        color: Theme.of(context).cardColor,
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                            color: Colors.black.withOpacity(0.05),
                                                                            blurRadius: 5,
                                                                          )
                                                                        ],
                                                                      ),
                                                                      padding: const EdgeInsets.all(12),
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Row(
                                                                            children: [
                                                                              Expanded(
                                                                                child: Text(
                                                                                  activity['title'] ?? '',
                                                                                  style: TextStyle(
                                                                                    fontWeight: FontWeight.bold,
                                                                                    fontSize: 15,
                                                                                    color: finished ? Colors.grey : null,
                                                                                    decoration: finished ? TextDecoration.lineThrough : TextDecoration.none,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              if (activity['isBooked'] == true)
                                                                                Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Colors.green[100],
                                                                                    borderRadius: BorderRadius.circular(20),
                                                                                  ),
                                                                                  child: Row(
                                                                                    children: [
                                                                                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                                                                      const SizedBox(width: 4),
                                                                                      Text(
                                                                                        localizations.translate('booked_status'),
                                                                                        style: const TextStyle(
                                                                                          color: Colors.green,
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontSize: 12,
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              const SizedBox(width: 8),
                                                                              GestureDetector(
                                                                                onTap: () => _confirmDeleteActivity(context, activityId, activity['title'] ?? ''),
                                                                                child: const Icon(Icons.delete_forever, size: 20, color: Colors.redAccent),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          const SizedBox(height: 6),
                                                                          Text(
                                                                            activity['description'] ?? '',
                                                                            style: const TextStyle(fontSize: 13),
                                                                          ),
                                                                          const SizedBox(height: 8),
                                                                          Row(
                                                                            children: [
                                                                              const Icon(Icons.location_on_outlined,
                                                                                  size: 16, color: Colors.grey),
                                                                              const SizedBox(width: 4),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  activity['location'] ?? '',
                                                                                  style: const TextStyle(
                                                                                      fontSize: 13, color: Colors.grey),
                                                                                ),
                                                                              ),
                                                                              const Spacer(),
                                                                              if (activity['price'] != null)
                                                                                Text(
                                                                                  '₱${activity['price']}',
                                                                                  style: const TextStyle(
                                                                                      fontWeight: FontWeight.bold, fontSize: 13),
                                                                                ),
                                                                            ],
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      );
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateActivityPage(itineraryId: itineraryId),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: Text(localizations.translate('add_activity')),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: ElevatedButton(
                  onPressed: () {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    _editTrip(context, data);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(localizations.translate('edit_trip')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
