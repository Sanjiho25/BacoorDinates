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
  final String _voiceId = '21m00Tcm4TlvDq8ikWAM';
  final String _baseUrl = 'https://api.elevenlabs.io/v1/text-to-speech';

  Future<bool> speak(String text) async {
    if (text.isEmpty) return false;
    if (_apiKey.isEmpty || _apiKey == 'YOUR_ELEVENLABS_API_KEY') {
      print('ElevenLabs API key is not configured.');
      return false;
    }

    try {
      final uri = Uri.parse('$_baseUrl/$_voiceId');
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
        },
        body: jsonEncode({
          'text': text,
          'voice_settings': {
            'stability': 0.75,
            'similarity_boost': 0.7,
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
