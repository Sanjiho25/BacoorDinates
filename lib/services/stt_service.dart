import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  static final SttService instance = SttService._();
  SttService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  // Maps your app language names to BCP-47 locale codes
  static const Map<String, String> _localeMap = {
    'English':    'en-US',
    'Filipino':   'fil-PH',
    'Japanese':   'ja-JP',
    'Korean':     'ko-KR',
    'Chinese':    'zh-CN',
    'Taiwanese':  'zh-TW',
    'Singaporean':'ms-SG',
    'Malaysian':  'ms-MY',
  };

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => print('STT error: $error'),
      onStatus: (status) => print('STT status: $status'),
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required String language,
    required Function(String text) onResult,
    required Function() onDone,
  }) async {
    final ready = await initialize();
    if (!ready) return;

    final locale = _localeMap[language] ?? 'en-US';

    await _speech.listen(
      localeId: locale,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      partialResults: true,
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onDone();
        } else if (result.recognizedWords.isNotEmpty) {
          // Show partial results live in the text field
          onResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> cancel() async {
    await _speech.cancel();
  }

  bool get isListening => _speech.isListening;
}