import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';

import '../services/eleven_labs_tts_service.dart';
import '../services/tts_utils.dart';
import 'package:untitled/l10n/app_localizations.dart';

class ARViewerScreen extends StatefulWidget {
  const ARViewerScreen({super.key});

  @override
  State<ARViewerScreen> createState() => _ARViewerScreenState();
}

class _ARViewerScreenState extends State<ARViewerScreen> {
  List<DocumentSnapshot> _nearbyARObjects = [];
  DocumentSnapshot? _selectedARObject;
  final FlutterTts flutterTts = FlutterTts();
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _loadNearbyARObjects();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      String languageCode = Localizations.localeOf(context).languageCode;
      if (languageCode == 'tl') {
        languageCode = 'tl-PH';
      }
      await TtsUtils.configureTts(
        flutterTts,
        languageCode,
        speechRate: 0.34,
        pitch: 1.0,
        volume: 1.0,
      );

      flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            isSpeaking = false;
          });
        }
      });
    } catch (e) {
      debugPrint('ARViewerScreen TTS initialization failed: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    if (isSpeaking) {
      await ElevenLabsTtsService.instance.stop();
      await flutterTts.stop();
      setState(() {
        isSpeaking = false;
      });
      return;
    }

    setState(() {
      isSpeaking = true;
    });

    String languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'tl') {
      languageCode = 'tl-PH';
    }

    final elevenSuccess = await ElevenLabsTtsService.instance.speak(
      text,
      languageCode: languageCode,
    );
    if (elevenSuccess) {
      setState(() {
        isSpeaking = false;
      });
      return;
    }

    await TtsUtils.configureTts(
      flutterTts,
      languageCode,
      speechRate: 0.32,
      pitch: 1.0,
      volume: 1.0,
    );

    final normalizedText = TtsUtils.normalizeText(text);
    await flutterTts.setQueueMode(1);
    await flutterTts.speak(normalizedText);
  }

  Future<void> _loadNearbyARObjects() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('Location services are disabled. Skipping AR object lookup.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied. Skipping AR object lookup.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final snapshot =
          await FirebaseFirestore.instance.collection('ar_objects').get();

      setState(() {
        _nearbyARObjects = snapshot.docs.where((doc) {
          final data = doc.data();
          final double docLat = data['latitude'];
          final double docLng = data['longitude'];
          final distance = _calculateDistance(
              position.latitude, position.longitude, docLat, docLng);
          return distance < 1; // 1 km radius
        }).toList();
      });
    } catch (e, st) {
      debugPrint('Error loading AR objects: $e');
      debugPrint('$st');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  void _selectARObject(DocumentSnapshot arObject) {
    setState(() {
      _selectedARObject = arObject;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context).translate('nearby_ar_objects'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        centerTitle: false,
        elevation: 0.5,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDarkMode ? const Color(0xFF1C1C1E) : Colors.grey[50]!,
              isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Card list
            SizedBox(
              height: 200,
              child: _nearbyARObjects.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)
                            .translate('no_nearby_ar_objects'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _nearbyARObjects.length,
                      itemBuilder: (context, index) {
                        final doc = _nearbyARObjects[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () => _selectARObject(doc),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedARObject?.id == doc.id
                                  ? theme.colorScheme.secondary
                                      .withValues(alpha: 0.15)
                                  : theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedARObject?.id == doc.id
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.view_in_ar,
                                    size: 40,
                                    color: _selectedARObject?.id == doc.id
                                        ? const Color(0xFF4080FF)
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    data['title'] ?? 'Untitled',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _selectedARObject?.id == doc.id
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // AR Viewer
            Expanded(
              child: _selectedARObject != null
                  ? Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ModelViewer(
                                key: ValueKey(_selectedARObject
                                    ?.id), // Add key to force rebuild
                                src: _selectedARObject!['file_url'] ?? '',
                                alt: _selectedARObject!['title'] ?? '3D model',
                                ar: true,
                                arModes: const [
                                  'scene-viewer',
                                  'webxr',
                                  'quick-look'
                                ],
                                autoRotate: true,
                                cameraControls: true,
                                backgroundColor: theme.scaffoldBackgroundColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_selectedARObject != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _speak(
                                      _selectedARObject!['description'] ?? ''),
                                  icon: Icon(isSpeaking
                                      ? Icons.stop
                                      : Icons.volume_up),
                                  label: Text(isSpeaking
                                      ? AppLocalizations.of(context)
                                          .translate('stop_speaking')
                                      : AppLocalizations.of(context)
                                          .translate('speak_description')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD700),
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Text(
                        AppLocalizations.of(context)
                            .translate('select_ar_object_to_view'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
