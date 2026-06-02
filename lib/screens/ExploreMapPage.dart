import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ExploreMapPage extends StatefulWidget {
  final double placeLat;
  final double placeLng;
  final String placeTitle;

  const ExploreMapPage({
    super.key,
    required this.placeLat,
    required this.placeLng,
    required this.placeTitle,
  });

  @override
  State<ExploreMapPage> createState() => _ExploreMapPageState();
}

class _ExploreMapPageState extends State<ExploreMapPage> with SingleTickerProviderStateMixin {
  LatLng? userLocation;
  List<LatLng> routePoints = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final MapController _mapController = MapController();
  double _currentZoom = 14.0;
  double _distance = 0;
  double _duration = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How to Use', 
          style: TextStyle(color: Theme.of(context).colorScheme.primary)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpRow(Icons.my_location, 'Tap to focus on your location'),
            const SizedBox(height: 12),
            _buildHelpRow(Icons.place, 'Tap to focus on destination'),
            const SizedBox(height: 12),
            _buildHelpRow(Icons.refresh, 'Tap to refresh route'),
            const SizedBox(height: 12),
            _buildHelpRow(Icons.zoom_in, 'Pinch to zoom in/out'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it!', 
              style: TextStyle(color: Theme.of(context).colorScheme.primary)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _setup();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      await _getCurrentLocation();
      if (userLocation != null) {
        await _fetchRoute();
      }
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load map: ${e.toString()}';
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        setState(() {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    setState(() {
      userLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _fetchRoute() async {
    const apiKey = '5b3ce3597851110001cf624863c27e70a3c24d2a824a6f8f5d76802f';
    final start = '${userLocation!.longitude},${userLocation!.latitude}';
    final end = '${widget.placeLng},${widget.placeLat}';

    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-walking?api_key=$apiKey&start=$start&end=$end',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coordinates = data['features'][0]['geometry']['coordinates'];
      final summary = data['features'][0]['properties']['summary'];

      final points = coordinates.map<LatLng>((coord) {
        return LatLng(coord[1], coord[0]);
      }).toList();

      setState(() {
        routePoints = points;
        _distance = summary['distance'] / 1000; // Convert to km
        _duration = summary['duration'] / 60; // Convert to minutes
        _isLoading = false;
      });

      _adjustMapView();
    } else {
      setState(() {
        _errorMessage = 'Failed to load route: ${response.statusCode}';
        _isLoading = false;
      });
    }
  }

  void _adjustMapView() {
    if (userLocation == null) return;

    final center = LatLng(
      (userLocation!.latitude + widget.placeLat) / 2,
      (userLocation!.longitude + widget.placeLng) / 2,
    );

    final latDiff = (userLocation!.latitude - widget.placeLat).abs();
    final lngDiff = (userLocation!.longitude - widget.placeLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    double zoom = 14 - maxDiff * 5;
    zoom = zoom.clamp(10.0, 16.0);

    _currentZoom = zoom;
    _mapController.move(center, zoom);
  }

  Future<void> _zoomToUserLocation() async {
    if (userLocation != null) {
      await _animatedMove(userLocation!, _currentZoom);
    }
  }

  Future<void> _zoomToDestination() async {
    await _animatedMove(LatLng(widget.placeLat, widget.placeLng), _currentZoom);
  }

  Future<void> _animatedMove(LatLng destination, double zoom) async {
    const duration = Duration(milliseconds: 800);
    const steps = 30;
    final latStep = (destination.latitude - _mapController.camera.center.latitude) / steps;
    final lngStep = (destination.longitude - _mapController.camera.center.longitude) / steps;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(duration ~/ steps);
      _mapController.move(
        LatLng(
          _mapController.camera.center.latitude + latStep,
          _mapController.camera.center.longitude + lngStep,
        ),
        zoom,
      );
    }
    _mapController.move(destination, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final placeLocation = LatLng(widget.placeLat, widget.placeLng);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back to previous screen',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.placeTitle,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('How to Use', style: TextStyle(color: colorScheme.primary)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHelpRow(Icons.my_location, 'Tap to focus on your location'),
                      const SizedBox(height: 12),
                      _buildHelpRow(Icons.place, 'Tap to focus on destination'),
                      const SizedBox(height: 12),
                      _buildHelpRow(Icons.refresh, 'Tap to refresh route'),
                      const SizedBox(height: 12),
                      _buildHelpRow(Icons.zoom_in, 'Pinch to zoom in/out'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Got it!', style: TextStyle(color: colorScheme.primary)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
              await _setup();
            },
            tooltip: 'Refresh route',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: placeLocation,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                InteractiveFlag.flingAnimation |
                InteractiveFlag.pinchMove |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.untitled',
              ),
              if (userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation!,
                      width: 55,
                      height: 55,
                      child: Tooltip(
                        message: 'Your current location',
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(27.5),
                            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_pin_circle,
                            color: colorScheme.primary,
                            size: 45,
                          ),
                        ),
                      ),
                    ),
                    Marker(
                      point: placeLocation,
                      width: 55,
                      height: 55,
                      child: Tooltip(
                        message: 'Destination: ${widget.placeTitle}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(27.5),
                            border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.error.withValues(alpha: 0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: colorScheme.error,
                            size: 45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,                    color: const Color(0xFF4080FF).withValues(alpha: 0.8),
                      strokeWidth: 5,
                      borderColor: Colors.white.withValues(alpha: 0.5),
                      borderStrokeWidth: 7,
                    ),
                  ],
                ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading route...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_errorMessage.isNotEmpty)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _errorMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Route Details at Top Center
          if (routePoints.isNotEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoRow(
                        context,
                        Icons.directions_walk,
                        'Distance',
                        '${_distance.toStringAsFixed(1)} km',
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      _buildInfoRow(
                        context,
                        Icons.timer,
                        'Duration',
                        '${_duration.toStringAsFixed(0)} min',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Zoom Buttons at Bottom Left
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                        child: MaterialButton(
                          onPressed: _zoomToUserLocation,
                          color: colorScheme.surface,
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.my_location,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                      ),
                      Container(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
                        child: MaterialButton(
                          onPressed: _zoomToDestination,
                          color: colorScheme.surface,
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.place,
                            color: colorScheme.error,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}