import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/io.dart';

class EdgeTtsService {
  static final EdgeTtsService instance = EdgeTtsService._();
  EdgeTtsService._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _completionSub;

  // Google Translate TTS language codes (best for Filipino)
  static const Map<String, String> _googleLangCodes = {
    'tl-PH': 'tl',
    'ms-MY': 'ms',
    'ms-SG': 'ms',
  };

  // Languages to use Google TTS for (better quality than Edge for these)
  static const Set<String> _useGoogleTts = {'tl-PH', 'ms-MY', 'ms-SG'};

  // Best Edge neural voices per language code
  static const Map<String, String> _voiceMap = {
    'en-US': 'en-US-AriaNeural',
    'en-GB': 'en-GB-SoniaNeural',
    'ja-JP': 'ja-JP-NanamiNeural',
    'ko-KR': 'ko-KR-SunHiNeural',
    'zh-CN': 'zh-CN-XiaoxiaoNeural',
    'zh-TW': 'zh-TW-HsiaoChenNeural',
  };

  // Speaking rate per language
  static const Map<String, String> _rateMap = {
    'zh-CN': '-10%',
    'zh-TW': '-10%',
    'ja-JP': '-8%',
    'ko-KR': '-8%',
    'en-US': '+0%',
  };

  /// Register a one-time callback that fires when playback finishes.
  void onPlaybackComplete(VoidCallback callback) {
    _completionSub?.cancel();
    _completionSub = _player.onPlayerComplete.listen((_) {
      _completionSub?.cancel();
      _completionSub = null;
      callback();
    });
  }

  /// Main entry point — picks Google or Edge TTS based on language
  Future<bool> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) return false;

    if (_useGoogleTts.contains(languageCode)) {
      return await _speakWithGoogle(text, languageCode);
    } else {
      return await _speakWithEdge(text, languageCode);
    }
  }

  /// Google Translate TTS — best for Filipino/Tagalog, Malay
  Future<bool> _speakWithGoogle(String text, String languageCode) async {
    try {
      final googleLang = _googleLangCodes[languageCode] ?? 'tl';

      final chunks = _splitTextIntoChunks(text, 200);
      final allBytes = <int>[];

      for (final chunk in chunks) {
        final encoded = Uri.encodeComponent(chunk);
        final url = Uri.parse(
          'https://translate.google.com/translate_tts'
          '?ie=UTF-8&q=$encoded&tl=$googleLang&client=tw-ob&ttsspeed=0.9',
        );

        final response = await http.get(url, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/121.0.0.0 Safari/537.36',
          'Referer': 'https://translate.google.com/',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) return false;
        allBytes.addAll(response.bodyBytes);
      }

      if (allBytes.isEmpty) return false;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/google_tts_output.mp3');
      await file.writeAsBytes(allBytes);

      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;
    } catch (e) {
      print('Google TTS error: $e');
      return false;
    }
  }

  /// Microsoft Edge TTS — best for Japanese, Korean, Chinese, English
  Future<bool> _speakWithEdge(String text, String languageCode) async {
    final voice = _voiceMap[languageCode] ?? _voiceMap['en-US']!;
    final rate = _rateMap[languageCode] ?? '+0%';
    final requestId = _generateRequestId();
    final timestamp = _getTimestamp();

    try {
      final wsUrl = Uri.parse(
        'wss://speech.platform.bing.com/consumer/speech/synthesize/'
        'readaloud/edge/v1?trustedclienttoken='
        '6A5AA1D4EAFF4E9FB37E23D68491D6F4'
        '&ConnectionId=$requestId',
      );

      final channel = IOWebSocketChannel.connect(
        wsUrl,
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'Accept-Encoding': 'gzip, deflate, br',
          'Accept-Language': 'en-US,en;q=0.9',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0',
        },
      );

      channel.sink.add(
        'X-Timestamp:$timestamp\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":'
        '{"sentenceBoundaryEnabled":false,"wordBoundaryEnabled":false},'
        '"outputFormat":"audio-24khz-96kbitrate-mono-mp3"}}}}',
      );

      final ssml = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="$languageCode">
  <voice name="$voice">
    <prosody rate="$rate" pitch="+0Hz">
      ${_escapeXml(text)}
    </prosody>
  </voice>
</speak>''';

      channel.sink.add(
        'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:$timestamp\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml',
      );

      final audioChunks = <int>[];
      final completer = Completer<bool>();

      channel.stream.listen(
        (message) {
          if (message is List<int>) {
            final separator = 'Path:audio\r\n\r\n'.codeUnits;
            int sepIndex = _findSequence(message, separator);
            if (sepIndex != -1) {
              audioChunks
                  .addAll(message.sublist(sepIndex + separator.length));
            }
          } else if (message is String) {
            if (message.contains('Path:turn.end')) {
              if (!completer.isCompleted) completer.complete(true);
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted)
            completer.complete(audioChunks.isNotEmpty);
        },
      );

      final success = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );

      await channel.sink.close();

      if (!success || audioChunks.isEmpty) return false;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/edge_tts_output.mp3');
      await file.writeAsBytes(audioChunks);

      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;
    } catch (e) {
      print('Edge TTS error: $e');
      return false;
    }
  }

  Future<void> stop() async {
    _completionSub?.cancel();
    _completionSub = null;
    await _player.stop();
  }

  List<String> _splitTextIntoChunks(String text, int maxLength) {
    if (text.length <= maxLength) return [text];

    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?,;])\s+'));

    String current = '';
    for (final sentence in sentences) {
      if ((current + sentence).length > maxLength && current.isNotEmpty) {
        chunks.add(current.trim());
        current = sentence;
      } else {
        current += (current.isEmpty ? '' : ' ') + sentence;
      }
    }
    if (current.trim().isNotEmpty) chunks.add(current.trim());
    return chunks;
  }

  String _generateRequestId() {
    final random = Random();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  String _getTimestamp() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        'T${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}'
        '.${now.millisecond.toString().padLeft(3, '0')}Z';
  }

  int _findSequence(List<int> data, List<int> sequence) {
    for (int i = 0; i <= data.length - sequence.length; i++) {
      bool found = true;
      for (int j = 0; j < sequence.length; j++) {
        if (data[i + j] != sequence[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}