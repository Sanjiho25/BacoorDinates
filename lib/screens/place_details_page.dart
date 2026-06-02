import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../providers/language_provider.dart';
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

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> speakText(String text, String langCode) async {
    try {
      await flutterTts.setLanguage(langCode);
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);

      if (!mounted) return;
      setState(() => _isSpeaking = true);

      await flutterTts.speak(text).whenComplete(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  String mapLocaleToTtsLang(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.countryCode == 'TW') return 'zh-TW';
      if (locale.countryCode == 'SG') return 'zh-SG';
      return 'zh-CN';
    }
    if (locale.languageCode == 'tl') {
      return 'tl-PH';
    }
    return locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final currentLocale = Provider.of<LanguageProvider>(context).currentLocale;
    final selectedLangCode = mapLocaleToTtsLang(currentLocale);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('places').doc(widget.placeId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Scaffold(body: _buildShimmerEffect());

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(body: Center(child: Text(localizations.translate('place_not_found'))));
        }

        final place = snapshot.data!;
        final data = place.data() as Map<String, dynamic>? ?? {};
        final originalDescription = (data['description'] ?? '').toString();

        if (!_likesInitialized) {
          _likes = (data['likes'] is int) ? data['likes'] as int : int.tryParse('${data['likes']}') ?? 0;
          _likesInitialized = true;
        }

        final translationFuture = GoogleTranslator().translate(originalDescription, to: mapLocaleToTtsLang(currentLocale));

        return FutureBuilder<Translation>(
          future: translationFuture,
          builder: (context, tSnap) {
            final translatedDescription = tSnap.data?.text ?? originalDescription;

            return Scaffold(
              body: CustomScrollView(
                slivers: [
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
                        child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: 'place_${widget.placeId}_image',
                        child: data['imageUrl'] != null
                            ? Image.network(data['imageUrl'], fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => Container(color: Colors.grey[300]))
                            : Container(color: Colors.grey[300]),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['title'] ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          // Likes row
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _likeProcessing
                                    ? null
                                    : () async {
                                        setState(() => _likeProcessing = true);
                                        final delta = _liked ? -1 : 1;
                                        setState(() {
                                          _liked = !_liked;
                                          _likes = (_likes) + delta;
                                        });
                                        try {
                                          await FirebaseFirestore.instance.collection('places').doc(widget.placeId).update({'likes': FieldValue.increment(delta)});
                                        } catch (_) {
                                          setState(() {
                                            _liked = !_liked;
                                            _likes = (_likes) - delta;
                                          });
                                        } finally {
                                          await Future.delayed(const Duration(milliseconds: 300));
                                          if (mounted) setState(() => _likeProcessing = false);
                                        }
                                      },
                                child: AnimatedScale(
                                  scale: _liked ? 1.15 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('$_likes ${localizations.translate('likes')}', style: const TextStyle(fontSize: 16)),
                            ],
                          ),

                          const SizedBox(height: 12),

                          if (data['rating'] != null) ...[
                            Row(children: List.generate(5, (i) => Icon(i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber))),
                            const SizedBox(height: 12),
                          ],

                          if (data['tags'] is List && (data['tags'] as List).isNotEmpty) ...[
                            Wrap(spacing: 8, runSpacing: 6, children: (data['tags'] as List).map<Widget>((t) => Chip(label: Text('$t'))).toList()),
                            const SizedBox(height: 12),
                          ],

                          // Description — plain, outside of a Card
                          Text(localizations.translate('description'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          LayoutBuilder(builder: (context, constraints) {
                            final text = translatedDescription;
                            final shouldShowToggle = text.length > 220;
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                text,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: _expanded ? null : 4,
                                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                              ),
                              if (shouldShowToggle)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => setState(() => _expanded = !_expanded),
                                    child: Text(_expanded ? localizations.translate('show_less') : localizations.translate('read_more')),
                                  ),
                                ),
                            ]);
                          }),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                            label: Text(_isSpeaking ? localizations.translate('stop') : localizations.translate('listen')),
                            onPressed: () => _isSpeaking ? flutterTts.stop() : speakText(translatedDescription, selectedLangCode),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                            icon: const Icon(Icons.explore),
                            label: Text(localizations.translate('explore')),
                            onPressed: () async {
                              final doc = await FirebaseFirestore.instance.collection('places').doc(widget.placeId).get();
                              if (doc.exists) {
                                final d = doc.data()!;
                                final double lat = double.tryParse('${d['lat']}') ?? 0.0;
                                final double lng = double.tryParse('${d['long']}') ?? 0.0;
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreMapPage(placeLat: lat, placeLng: lng, placeTitle: d['title'] ?? '')));
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
            child: Container(width: double.infinity, height: 20, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(width: double.infinity, height: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}