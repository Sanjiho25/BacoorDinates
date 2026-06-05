import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class GoogleTtsService {
  static final GoogleTtsService instance = GoogleTtsService._();
  GoogleTtsService._();

  // Get a free API key from: https://console.cloud.google.com
  // Enable "Cloud Text-to-Speech API" — 1M chars/month free
  static const String _apiKey = 'YOUR_GOOGLE_CLOUD_API_KEY';

  final AudioPlayer _player = AudioPlayer();

  // Best free Neural2 voices per language
  static const Map<String, Map<String, String>> _voiceConfig = {
    'en-US': {
      'languageCode': 'en-US',
      'name': 'en-US-Neural2-F',      // natural American female
    },
    'tl-PH': {
      'languageCode': 'fil-PH',
      'name': 'fil-PH-Neural2-A',     // Filipino female
    },
    'ja-JP': {
      'languageCode': 'ja-JP',
      'name': 'ja-JP-Neural2-B',      // Japanese female
    },
    'ko-KR': {
      'languageCode': 'ko-KR',
      'name': 'ko-KR-Neural2-A',      // Korean female
    },
    'zh-CN': {
      'languageCode': 'cmn-CN',
      'name': 'cmn-CN-Neural2-A',     // Mandarin female
    },
    'zh-TW': {
      'languageCode': 'cmn-TW',
      'name': 'cmn-TW-Wavenet-A',     // Taiwanese Mandarin
    },
    'ms-MY': {
      'languageCode': 'ms-MY',
      'name': 'ms-MY-Standard-A',     // Malay (no Neural2 yet)
    },
    'ms-SG': {
      'languageCode': 'ms-MY',
      'name': 'ms-MY-Standard-A',
    },
  };

  /// Returns true if spoken successfully, false to trigger fallback
  Future<bool> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) return false;

    try {
      final voice = _voiceConfig[languageCode] ?? _voiceConfig['en-US']!;

      final response = await http.post(
        Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': voice['languageCode'],
            'name': voice['name'],
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': _getSpeakingRate(languageCode),
            'pitch': 0.0,
            'volumeGainDb': 1.0,
          },
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return false;

      final audioContent = jsonDecode(response.body)['audioContent'] as String?;
      if (audioContent == null) return false;

      // Save to temp file and play
      final bytes = base64Decode(audioContent);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gtts_output.mp3');
      await file.writeAsBytes(bytes);

      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;

    } catch (e) {
      print('Google TTS error: $e');
      return false; // triggers Flutter TTS fallback
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  double _getSpeakingRate(String languageCode) {
    switch (languageCode) {
      case 'zh-CN':
      case 'zh-TW':
        return 0.90;
      case 'ja-JP':
        return 0.92;
      case 'ko-KR':
        return 0.93;
      case 'tl-PH':
        return 0.95;
      default:
        return 1.0;
    }
  }
}