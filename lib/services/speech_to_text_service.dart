import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextService {
  SpeechToTextService._();
  static final SpeechToTextService instance = SpeechToTextService._();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    try {
      final available = await _speechToText.initialize(
        onError: (error) => print('Speech error: ${error.errorMsg}'),
        onStatus: (status) => print('Speech status: $status'),
      );
      return available;
    } catch (e) {
      print('Speech initialization error: $e');
      return false;
    }
  }

  void startListening({
    required Function(String) onResult,
    String languageCode = 'en-US',
  }) {
    if (!_speechToText.isAvailable || _isListening) return;

    _isListening = true;
    _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: languageCode,
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speechToText.stop();
  }

  Future<void> cancelListening() async {
    _isListening = false;
    await _speechToText.cancel();
  }
}
