import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'CustomPlaceCard.dart';
import '/l10n/app_localizations.dart';

class TabPlace extends StatefulWidget {
  const TabPlace({super.key});

  @override
  _TabPlaceState createState() => _TabPlaceState();
}

class _TabPlaceState extends State<TabPlace> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .orderBy('likes', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context).translate('no_search_results')),
          );
        }

        var places = snapshot.data!.docs.where((place) {
          final title = place['title'].toString().toLowerCase();
          final description = place['description'].toString().toLowerCase();
          final category = place['category'].toString().toLowerCase();
          return title.contains(_searchQuery) || 
                 description.contains(_searchQuery) ||
                 category.contains(_searchQuery);
        }).toList();

        if (places.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).translate('no_search_results'),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: places.length,
          itemBuilder: (context, index) {
            var place = places[index];
            return CustomPlaceCard(
              placeId: place.id,
              imageUrl: place['imageUrl'] ?? '',
              title: place['title'] ?? 'No Title',
              description: place['description'] ?? 'No Description',
              category: place['category'] ?? '',
              likes: place['likes'] ?? 0,
              likedBy: List<String>.from(place['likedBy'] ?? []),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).translate('search_places'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            TabBar(
              isScrollable: true,
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: [
                Tab(text: AppLocalizations.of(context).translate('popular')),
                Tab(text: AppLocalizations.of(context).translate('churches')),
                Tab(text: AppLocalizations.of(context).translate('historical')),
                Tab(text: AppLocalizations.of(context).translate('restaurants')),
                Tab(text: AppLocalizations.of(context).translate('hotels')),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPopularList(),
                  _buildCategoryList('Churches'),
                  _buildCategoryList('Historical'),
                  _buildCategoryList('Restaurants'),
                  _buildCategoryList('Hotels'),
                ],
              ),
            ),
          ] else
            // Show search results when searching
            Expanded(
              child: _buildSearchResults(),
            ),
        ],
      ),
    );
  }

  /// ✅ Fetches only places that have at least 1 like (for the Popular tab)
  Widget _buildPopularList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .where('likes', isGreaterThan: 0)
          .orderBy('likes', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No popular places yet!'));
        }

        var places = snapshot.data!.docs;
        
        // Filter places based on search query
        if (_searchQuery.isNotEmpty) {
          places = places.where((place) {
            final title = place['title'].toString().toLowerCase();
            final description = place['description'].toString().toLowerCase();
            return title.contains(_searchQuery) || description.contains(_searchQuery);
          }).toList();

          if (places.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).translate('no_search_results')),
            );
          }
        }

        return ListView.builder(
          itemCount: places.length,
          itemBuilder: (context, index) {
            var place = places[index];
            return CustomPlaceCard(
              placeId: place.id,
              imageUrl: place['imageUrl'] ?? '',
              title: place['title'] ?? 'No Title',
              description: place['description'] ?? 'No Description',
              category: place['category'] ?? '',
              likes: place['likes'] ?? 0,
              likedBy: List<String>.from(place['likedBy'] ?? []),
            );
          },
        );
      },
    );
  }

  /// ✅ Fetches places by category (for Churches, Historical, etc.)
  Widget _buildCategoryList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No places found in $category'));
        }

        var places = snapshot.data!.docs;

        // Filter places based on search query
        if (_searchQuery.isNotEmpty) {
          places = places.where((place) {
            final title = place['title'].toString().toLowerCase();
            final description = place['description'].toString().toLowerCase();
            return title.contains(_searchQuery) || description.contains(_searchQuery);
          }).toList();

          if (places.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).translate('no_search_results')),
            );
          }
        }

        return ListView.builder(
          itemCount: places.length,
          itemBuilder: (context, index) {
            var place = places[index];
            return CustomPlaceCard(
              placeId: place.id,
              imageUrl: place['imageUrl'] ?? '',
              title: place['title'] ?? 'No Title',
              description: place['description'] ?? 'No Description',
              category: place['category'] ?? '',
              likes: place['likes'] ?? 0,
              likedBy: List<String>.from(place['likedBy'] ?? []),
            );
          },
        );
      },
    );
  }
}
