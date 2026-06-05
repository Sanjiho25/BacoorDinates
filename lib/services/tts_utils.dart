import 'package:flutter_tts/flutter_tts.dart';

class TtsUtils {
  TtsUtils._();

  static Future<void> configureTts(
    FlutterTts flutterTts,
    String languageCode, {
    double speechRate = 0.38,
    double pitch = 1.05,
    double volume = 1.0,
    bool awaitCompletion = true,
  }) async {
    await flutterTts.setLanguage(languageCode);
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setPitch(pitch);
    await flutterTts.setVolume(volume);
    if (awaitCompletion) {
      await flutterTts.awaitSpeakCompletion(true);
    }
    await setBestVoice(flutterTts, languageCode);
  }

  static Future<void> setBestVoice(
      FlutterTts flutterTts, String languageCode) async {
    try {
      final voices = await flutterTts.getVoices;
      if (voices is List) {
        final matchedVoices = voices
            .whereType<Map<dynamic, dynamic>>()
            .where((voice) {
              final voiceName = '${voice['name'] ?? ''}'.toLowerCase();
              final voiceLocale = '${voice['locale'] ?? ''}'.toLowerCase();
              final baseLang = languageCode.split('-')[0].toLowerCase();
              return voiceLocale.contains(baseLang) || voiceName.contains(baseLang);
            })
            .toList();

        if (matchedVoices.isEmpty) return;

        matchedVoices.sort((a, b) =>
            _voiceScore(b).compareTo(_voiceScore(a)));

        final bestVoice = matchedVoices.first;
        final voiceName = bestVoice['name'];
        final voiceLocale = bestVoice['locale'] ?? languageCode;

        if (voiceName != null) {
          await flutterTts.setVoice({
            'name': voiceName,
            'locale': voiceLocale,
          });
        }
      }
    } catch (_) {
      // Ignore voice selection failures and continue with default engine voice.
    }
  }

  static int _voiceScore(Map<dynamic, dynamic> voice) {
    final name = '${voice['name'] ?? ''}'.toLowerCase();
    final locale = '${voice['locale'] ?? ''}'.toLowerCase();
    var score = 0;

    for (final keyword in [
      'neural',
      'natural',
      'enhanced',
      'alloy',
      'wave',
      'female',
      'male',
      'us',
      'uk',
      'en-us',
      'en-gb',
      'en-au',
      'en-in',
    ]) {
      if (name.contains(keyword) || locale.contains(keyword)) {
        score += 2;
      }
    }

    if (name.contains('male')) score -= 1;
    if (name.contains('child') || name.contains('kid')) score -= 2;
    return score;
  }

  static String normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('…', '...')
        .trim();
  }
}
