import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/language_provider.dart';
import '../services/eleven_labs_tts_service.dart';
import '../services/edge_tts_service.dart';
import '../services/tts_utils.dart';
import '../l10n/app_localizations.dart';
import 'ExploreMapPage.dart';

class PlaceDetailsPage extends StatefulWidget {
  final String placeId;

  const PlaceDetailsPage({super.key, required this.placeId});

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _liked = false;
  int _likes = 0;
  bool _likesInitialized = false;
  bool _expanded = false;
  bool _likeProcessing = false;

  // ── Translation cache ───────────────────────────────────────────────────────
  // Cached future so rebuilds (e.g. from setState on listen-button tap) don't
  // fire a fresh network request every frame.
  Future<Translation>? _translationFuture;
  String _cachedOriginalDescription = '';
  Locale? _cachedLocale;

  @override
  void initState() {
    super.initState();
    _initTtsHandlers();
  }

  /// Register flutter_tts callbacks once so state stays in sync.
  void _initTtsHandlers() {
    flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    flutterTts.setErrorHandler((msg) {
      debugPrint('FlutterTts error: $msg');
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    ElevenLabsTtsService.instance.stop();
    EdgeTtsService.instance.stop();
    super.dispose();
  }

  // ── Language helpers ───────────────────────────────────────────────────────

  /// Maps app locale → BCP-47 code used by EdgeTtsService / FlutterTts.
  String mapLocaleToTtsLang(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        if (locale.countryCode == 'TW') return 'zh-TW';
        if (locale.countryCode == 'SG') return 'zh-SG';
        return 'zh-CN';
      case 'tl':
        return 'tl-PH'; // EdgeTtsService routes this to Google Translate TTS
      case 'en':
        return 'en-US';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'fr':
        return 'fr-FR';
      case 'es':
        return 'es-ES';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      case 'pt':
        return locale.countryCode == 'BR' ? 'pt-BR' : 'pt-PT';
      case 'ar':
        return 'ar-SA';
      case 'hi':
        return 'hi-IN';
      case 'th':
        return 'th-TH';
      case 'vi':
        return 'vi-VN';
      case 'id':
        return 'id-ID';
      case 'ms':
        return locale.countryCode == 'SG' ? 'ms-SG' : 'ms-MY';
      default:
        return locale.languageCode;
    }
  }

  /// Maps app locale → language code for GoogleTranslator.
  String mapLocaleToTranslationLang(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.countryCode == 'TW') return 'zh-tw';
      // zh-SG and zh-CN both use Simplified Chinese
      return 'zh-cn';
    }
    if (locale.languageCode == 'tl') return 'tl';
    if (locale.languageCode == 'ms') return 'ms';
    return locale.languageCode;
  }

  /// Returns (or rebuilds) the translation future only when the source text
  /// or target locale actually changes, preventing re-fetches on every build.
  Future<Translation> _getTranslationFuture(
      String originalDescription, Locale locale) {
    if (_translationFuture != null &&
        _cachedOriginalDescription == originalDescription &&
        _cachedLocale == locale) {
      return _translationFuture!;
    }
    _cachedOriginalDescription = originalDescription;
    _cachedLocale = locale;
    _translationFuture = GoogleTranslator().translate(
      originalDescription,
      to: mapLocaleToTranslationLang(locale),
    );
    return _translationFuture!;
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  /// Speaks [text] using the best available engine for [langCode].
  ///
  /// Priority:
  ///   1. ElevenLabs  — highest quality, requires API key
  ///   2. EdgeTtsService:
  ///      • tl-PH / ms-MY / ms-SG → Google Translate TTS (natural Tagalog)
  ///      • everything else        → Microsoft Edge neural voices
  ///   3. flutter_tts — device built-in, offline fallback
  Future<void> _speakText(String text, String langCode) async {
    if (text.trim().isEmpty) return;

    // 1. ElevenLabs
    final elevenSuccess = await ElevenLabsTtsService.instance.speak(
      text,
      languageCode: langCode,
    );
    if (elevenSuccess) {
      if (mounted) setState(() => _isSpeaking = true);
      return;
    }

    // 2. EdgeTtsService (Google Translate TTS for Tagalog, Edge for others)
    if (mounted) setState(() => _isSpeaking = true);
    try {
      final edgeSuccess = await EdgeTtsService.instance.speak(
        text,
        languageCode: langCode,
      );
      if (edgeSuccess) {
        // Audio is playing; use the public callback to reset the button
        EdgeTtsService.instance.onPlaybackComplete(() {
          if (mounted) setState(() => _isSpeaking = false);
        });
        return;
      }
    } catch (e) {
      debugPrint('EdgeTts error: $e');
    }

    // 3. flutter_tts fallback (offline)
    try {
      final normalizedText = TtsUtils.normalizeText(text);
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
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  /// Stops whichever TTS engine is currently playing.
  Future<void> _stopSpeaking() async {
    await ElevenLabsTtsService.instance.stop();
    await EdgeTtsService.instance.stop();
    await flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final currentLocale = Provider.of<LanguageProvider>(context).currentLocale;
    final selectedLangCode = mapLocaleToTtsLang(currentLocale);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('places')
          .doc(widget.placeId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: _buildShimmerEffect());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Text(localizations.translate('place_not_found')),
            ),
          );
        }

        final place = snapshot.data!;
        final data = place.data() as Map<String, dynamic>? ?? {};
        final originalDescription = (data['description'] ?? '').toString();

        if (!_likesInitialized) {
          _likes = (data['likes'] is int)
              ? data['likes'] as int
              : int.tryParse('${data['likes']}') ?? 0;
          _likesInitialized = true;
        }

        final translationFuture = _getTranslationFuture(
          originalDescription, currentLocale);

        return FutureBuilder<Translation>(
          future: translationFuture,
          builder: (context, tSnap) {
            final translatedDescription =
                tSnap.data?.text ?? originalDescription;

            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  // ── Hero App Bar ───────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 280,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    automaticallyImplyLeading: false,
                    leading: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.translucent,
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: 'place_${widget.placeId}_image',
                        child: data['imageUrl'] != null
                            ? Image.network(
                                data['imageUrl'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (c, e, s) =>
                                    Container(color: Colors.grey[300]),
                              )
                            : Container(color: Colors.grey[300]),
                      ),
                    ),
                  ),

                  // ── Body ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            data['title'] ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // ── Likes ──────────────────────────────────────
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _likeProcessing
                                    ? null
                                    : () async {
                                        setState(
                                            () => _likeProcessing = true);
                                        final delta = _liked ? -1 : 1;
                                        setState(() {
                                          _liked = !_liked;
                                          _likes += delta;
                                        });
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('places')
                                              .doc(widget.placeId)
                                              .update({
                                            'likes':
                                                FieldValue.increment(delta),
                                          });
                                        } catch (_) {
                                          setState(() {
                                            _liked = !_liked;
                                            _likes -= delta;
                                          });
                                        } finally {
                                          await Future.delayed(const Duration(
                                              milliseconds: 300));
                                          if (mounted) {
                                            setState(() =>
                                                _likeProcessing = false);
                                          }
                                        }
                                      },
                                child: AnimatedScale(
                                  scale: _liked ? 1.15 : 1.0,
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: Icon(
                                    _liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_likes ${localizations.translate('likes')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ── Star rating ────────────────────────────────
                          if (data['rating'] != null) ...[
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < (data['rating'] ?? 0)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Tags ───────────────────────────────────────
                          if (data['tags'] is List &&
                              (data['tags'] as List).isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: (data['tags'] as List)
                                  .map<Widget>(
                                      (t) => Chip(label: Text('$t')))
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Description ────────────────────────────────
                          Text(
                            localizations.translate('description'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // Shimmer while translation loads
                          if (tSnap.connectionState ==
                              ConnectionState.waiting) ...[
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Column(
                                children: List.generate(
                                  4,
                                  (_) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6.0),
                                    child: Container(
                                      width: double.infinity,
                                      height: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final shouldShowToggle =
                                    translatedDescription.length > 220;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      translatedDescription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      textAlign: TextAlign.justify,
                                      maxLines: _expanded ? null : 4,
                                      overflow: _expanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                    ),
                                    if (shouldShowToggle)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => setState(
                                              () => _expanded = !_expanded),
                                          child: Text(
                                            _expanded
                                                ? localizations
                                                    .translate('show_less')
                                                : localizations
                                                    .translate('read_more'),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Bottom buttons ─────────────────────────────────────────
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Listen / Stop
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: Icon(_isSpeaking
                                ? Icons.stop
                                : Icons.volume_up),
                            label: Text(
                              _isSpeaking
                                  ? localizations.translate('stop')
                                  : localizations.translate('listen'),
                            ),
                            onPressed: () async {
                              if (_isSpeaking) {
                                await _stopSpeaking();
                              } else {
                                await _speakText(
                                    translatedDescription, selectedLangCode);
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Explore
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: const Icon(Icons.explore),
                            label:
                                Text(localizations.translate('explore')),
                            onPressed: () async {
                              final doc = await FirebaseFirestore.instance
                                  .collection('places')
                                  .doc(widget.placeId)
                                  .get();
                              if (doc.exists && context.mounted) {
                                final d = doc.data()!;
                                final double lat =
                                    double.tryParse('${d['lat']}') ?? 0.0;
                                final double lng =
                                    double.tryParse('${d['long']}') ?? 0.0;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExploreMapPage(
                                      placeLat: lat,
                                      placeLng: lng,
                                      placeTitle: d['title'] ?? '',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────

  Widget _buildShimmerEffect() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
                width: double.infinity, height: 20, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
                width: double.infinity, height: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}