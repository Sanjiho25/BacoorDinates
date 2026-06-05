import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class ElevenLabsTtsService {
  ElevenLabsTtsService._();
  static final ElevenLabsTtsService instance = ElevenLabsTtsService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _apiKey = const String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: 'YOUR_ELEVENLABS_API_KEY',
  );
  final String _defaultVoiceId = const String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: 'VR6AewLIUMnocjkujllp', // Freya - warm & friendly
  );
  final String _tagalogVoiceId = const String.fromEnvironment(
    'ELEVENLABS_TAGALOG_VOICE_ID',
    defaultValue: 'VR6AewLIUMnocjkujllp', // Freya works well for Tagalog
  );
  final String _baseUrl = 'https://api.elevenlabs.io/v1/text-to-speech';

  String _voiceIdForLanguage(String languageCode) {
    final code = languageCode.toLowerCase();
    if (code.startsWith('tl')) {
      return _tagalogVoiceId.isNotEmpty ? _tagalogVoiceId : _defaultVoiceId;
    }
    return _defaultVoiceId;
  }

  Future<bool> speak(String text, {String languageCode = 'en-US'}) async {
    if (text.isEmpty) return false;
    if (_apiKey.isEmpty || _apiKey == 'YOUR_ELEVENLABS_API_KEY') {
      print('ElevenLabs API key is not configured.');
      return false;
    }

    final voiceId = _voiceIdForLanguage(languageCode);
    final uri = Uri.parse('$_baseUrl/$voiceId');
    try {
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.55,
            'similarity_boost': 0.85,
            'style': 0.5,
            'use_speaker_boost': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        print('ElevenLabs TTS failed: ${response.statusCode} ${response.body}');
        return false;
      }

      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/eleven_labs_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(bytes, flush: true);

      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();
      return true;
    } catch (e) {
      print('ElevenLabs TTS error: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }
}
