import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';

import 'package:translator/translator.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/eleven_labs_tts_service.dart';
import '../services/edge_tts_service.dart';
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

  // ── CATEGORY STATE ──────────────────────────────────────────────────────────
  String _selectedCategoryFilter = 'All';

  static const List<String> _categories = [
    'Monument',
    'Mural',
    'Site',
    'Artifact',
  ];

  static const Map<String, Color> _categoryBgColors = {
    'Monument': Color(0xFFE6F1FB),
    'Mural':    Color(0xFFEEEDFE),
    'Site':     Color(0xFFE1F5EE),
    'Artifact': Color(0xFFFAEEDA),
  };

  static const Map<String, Color> _categoryTextColors = {
    'Monument': Color(0xFF0C447C),
    'Mural':    Color(0xFF3C3489),
    'Site':     Color(0xFF085041),
    'Artifact': Color(0xFF633806),
  };

  static const Map<String, Color> _categoryDotColors = {
    'Monument': Color(0xFF378ADD),
    'Mural':    Color(0xFF7F77DD),
    'Site':     Color(0xFF1D9E75),
    'Artifact': Color(0xFFBA7517),
  };
  // ────────────────────────────────────────────────────────────────────────────

  List<DocumentSnapshot> get _filteredARObjects {
    if (_selectedCategoryFilter == 'All') return _nearbyARObjects;
    return _nearbyARObjects.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['category']?.toString() ?? '') == _selectedCategoryFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _initTtsHandlers();
    _loadNearbyARObjects();
  }

  /// Register flutter_tts callbacks once so state stays in sync.
  void _initTtsHandlers() {
    flutterTts.setStartHandler(() {
      if (mounted) setState(() => isSpeaking = true);
    });
    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => isSpeaking = false);
    });
    flutterTts.setCancelHandler(() {
      if (mounted) setState(() => isSpeaking = false);
    });
    flutterTts.setErrorHandler((msg) {
      debugPrint('FlutterTts error: $msg');
      if (mounted) setState(() => isSpeaking = false);
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    ElevenLabsTtsService.instance.stop();
    EdgeTtsService.instance.stop();
    super.dispose();
  }

  /// Gets the current locale from LanguageProvider (same source as the rest of the app).
  Locale _getCurrentLocale() {
    return Provider.of<LanguageProvider>(context, listen: false).currentLocale;
  }

  /// Maps locale → BCP-47 code used by EdgeTtsService.
  String _getTtsLangCode() {
    final locale = _getCurrentLocale();
    switch (locale.languageCode) {
      case 'tl': return 'tl-PH'; // → EdgeTtsService routes to Google Translate TTS
      case 'zh':
        if (locale.countryCode == 'TW') return 'zh-TW';
        if (locale.countryCode == 'SG') return 'zh-SG';
        return 'zh-CN';
      case 'en': return 'en-US';
      case 'ja': return 'ja-JP';
      case 'ko': return 'ko-KR';
      case 'fr': return 'fr-FR';
      case 'es': return 'es-ES';
      case 'de': return 'de-DE';
      case 'it': return 'it-IT';
      case 'ms':
        return locale.countryCode == 'SG' ? 'ms-SG' : 'ms-MY';
      default:   return locale.languageCode;
    }
  }

  /// Maps locale → language code for GoogleTranslator.
  String _getTranslationLangCode() {
    final locale = _getCurrentLocale();
    if (locale.languageCode == 'zh') {
      if (locale.countryCode == 'TW') return 'zh-TW';
      if (locale.countryCode == 'SG') return 'zh-SG';
      return 'zh-CN';
    }
    if (locale.languageCode == 'tl') return 'tl';
    return locale.languageCode;
  }

  /// Translates [text] to the currently selected app language.
  /// Returns the original text if already in English or translation fails.
  Future<String> _translateText(String text) async {
    final targetLang = _getTranslationLangCode();
    // Skip translation if target is English (description is already English)
    if (targetLang == 'en') return text;
    try {
      final translation = await GoogleTranslator().translate(
        text,
        from: 'en',
        to: targetLang,
      );
      return translation.text;
    } catch (e) {
      debugPrint('Translation error: $e');
      return text; // fall back to original
    }
  }

  /// Translates [text] to the selected language then speaks it.
  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    // Tap again while speaking = stop
    if (isSpeaking) {
      await ElevenLabsTtsService.instance.stop();
      await EdgeTtsService.instance.stop();
      await flutterTts.stop();
      if (mounted) setState(() => isSpeaking = false);
      return;
    }

    final langCode = _getTtsLangCode();

    // Translate the description to the currently selected language first
    final translatedText = await _translateText(text);

    // 1. ElevenLabs
    final elevenSuccess = await ElevenLabsTtsService.instance.speak(
      translatedText,
      languageCode: langCode,
    );
    if (elevenSuccess) {
      if (mounted) setState(() => isSpeaking = true);
      return;
    }

    // 2. EdgeTtsService (Google Translate TTS for Tagalog, Edge for others)
    if (mounted) setState(() => isSpeaking = true);
    try {
      final edgeSuccess = await EdgeTtsService.instance.speak(
        translatedText,
        languageCode: langCode,
      );
      if (edgeSuccess) {
        EdgeTtsService.instance.onPlaybackComplete(() {
          if (mounted) setState(() => isSpeaking = false);
        });
        return;
      }
    } catch (e) {
      debugPrint('EdgeTts error: $e');
    }

    // 3. flutter_tts fallback (offline)
    try {
      final normalizedText = TtsUtils.normalizeText(translatedText);
      final bool isAvailable =
          await flutterTts.isLanguageAvailable(langCode) == true;

      await flutterTts.setLanguage(isAvailable ? langCode : 'en-US');
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setPitch(1.0);
      await flutterTts.setVolume(1.0);

      if (!mounted) return;
      await flutterTts.speak(normalizedText);
    } catch (e) {
      debugPrint('FlutterTts fallback error: $e');
      if (mounted) setState(() => isSpeaking = false);
    }
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
    const earthRadius = 6371;
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
    setState(() => _selectedARObject = arObject);
  }

  // ── CATEGORY HELPERS ──────────────────────────────────────────────────────

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Monument': return Icons.account_balance;
      case 'Mural':    return Icons.brush;
      case 'Site':     return Icons.location_city;
      case 'Artifact': return Icons.museum;
      default:         return Icons.view_in_ar;
    }
  }

  Widget _buildCategoryBadge(String category) {
    final bg   = _categoryBgColors[category]   ?? Colors.grey.shade200;
    final text = _categoryTextColors[category] ?? Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(category), size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            category,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: text),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRow(bool isDarkMode, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: ['All', ..._categories].map((cat) {
          final isActive = _selectedCategoryFilter == cat;
          final dot = _categoryDotColors[cat];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryFilter = cat;
                if (_selectedARObject != null && cat != 'All') {
                  final selData =
                      _selectedARObject!.data() as Map<String, dynamic>;
                  if ((selData['category']?.toString() ?? '') != cat) {
                    _selectedARObject = null;
                  }
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF4080FF)
                    : (isDarkMode
                        ? const Color(0xFF1C1C2E)
                        : Colors.grey[200]!),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF4080FF)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null) ...[
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white70 : dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context).translate('nearby_ar_objects'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : theme.colorScheme.primary,
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
            // ── CATEGORY FILTER PILLS ────────────────────────────────
            _buildCategoryFilterRow(isDarkMode, theme),

            // ── CAROUSEL ─────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: _filteredARObjects.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)
                            .translate('no_nearby_ar_objects'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredARObjects.length,
                      itemBuilder: (context, index) {
                        final doc = _filteredARObjects[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final category =
                            data['category']?.toString() ?? '';

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
                                  color:
                                      Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _selectedARObject?.id ==
                                              doc.id
                                          ? const Color(0xFF4080FF)
                                              .withOpacity(0.15)
                                          : (_categoryBgColors[
                                                  category] ??
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withOpacity(0.4)),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _categoryIcon(category),
                                      size: 28,
                                      color: _selectedARObject?.id ==
                                              doc.id
                                          ? const Color(0xFF4080FF)
                                          : (_categoryTextColors[
                                                  category] ??
                                              theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data['title'] ?? 'Untitled',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _selectedARObject?.id ==
                                              doc.id
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (category.isNotEmpty)
                                    _buildCategoryBadge(category),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── AR VIEWER ────────────────────────────────────────────
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
                                key: ValueKey(_selectedARObject?.id),
                                src: _selectedARObject!['file_url'] ?? '',
                                alt: _selectedARObject!['title'] ??
                                    '3D model',
                                ar: true,
                                arModes: const [
                                  'scene-viewer',
                                  'webxr',
                                  'quick-look',
                                ],
                                autoRotate: true,
                                cameraControls: true,
                                backgroundColor:
                                    theme.scaffoldBackgroundColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _speak(
                                    _selectedARObject!['description'] ??
                                        ''),
                                icon: Icon(isSpeaking
                                    ? Icons.stop
                                    : Icons.volume_up),
                                label: Text(
                                  isSpeaking
                                      ? AppLocalizations.of(context)
                                          .translate('stop_speaking')
                                      : AppLocalizations.of(context)
                                          .translate('speak_description'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFFFD700),
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
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