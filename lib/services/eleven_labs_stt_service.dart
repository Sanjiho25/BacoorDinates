import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ElevenLabsSttService {
  ElevenLabsSttService._();
  static final ElevenLabsSttService instance = ElevenLabsSttService._();

  final String _apiKey = const String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: '',
  );
  final String _endpoint = 'https://api.elevenlabs.io/v1/audio/transcriptions';
  final String _model = 'gpt-4o-transcribe';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<String?> transcribe(File audioFile, String locale) async {
    if (!isConfigured) {
      print('ElevenLabs STT API key is not configured.');
      return null;
    }

    try {
      final uri = Uri.parse(_endpoint);
      final request = http.MultipartRequest('POST', uri);
      request.headers['xi-api-key'] = _apiKey;
      request.fields['model'] = _model;
      request.fields['language'] = locale.split('-').first;
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        contentType: MediaType('audio', 'wav'),
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        print('ElevenLabs STT failed: ${response.statusCode} $responseBody');
        return null;
      }

      final json = jsonDecode(responseBody);
      if (json is Map<String, dynamic>) {
        return json['text']?.toString() ?? json['transcription']?.toString();
      }
      return responseBody.trim();
    } catch (e) {
      print('ElevenLabs STT error: $e');
      return null;
    }
  }
}
