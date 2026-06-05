import 'dart:async';
import 'dart:io' show Platform, File;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:untitled/l10n/app_localizations.dart';
import 'package:untitled/providers/theme_provider.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:http/http.dart' as http;
import '../services/eleven_labs_tts_service.dart';
import '../services/eleven_labs_stt_service.dart';
import '../services/tts_utils.dart';
import 'package:untitled/components/DarkModeToggle.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final _textController = TextEditingController();
  String _translatedText = '';
  String _selectedSourceLanguage = 'English';
  String _selectedTargetLanguage = 'Filipino';
  bool _isLoading = false;
  bool _isListening = false;
  final FlutterTts flutterTts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();
  String _errorMessage = '';

  final Map<String, String> _languageCodes = {
    'English': 'en-US',
    'Filipino': 'tl',
    'Japanese': 'ja-JP',
    'Korean': 'ko-KR',
    'Chinese': 'zh-CN',
    'Taiwanese': 'zh-TW',
    'Singaporean': 'ms-SG',
    'Malaysian': 'ms-MY',
  };

  final List<String> _languages = [
    'English',
    'Filipino',
    'Japanese',
    'Korean',
    'Chinese',
    'Taiwanese',
    'Singaporean',
    'Malaysian',
  ];

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    return _languages.map((String item) {
      return DropdownMenuItem<String>(
        value: item,
        child: Text(
          item,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }).toList();
  }

  final Map<String, String> _ttsLanguageCodes = {
    'English': 'en-US',
    'Filipino': 'tl-PH',
    'Japanese': 'ja-JP',
    'Korean': 'ko-KR',
    'Chinese': 'zh-CN',
    'Taiwanese': 'zh-TW',
    'Singaporean': 'ms-SG',
    'Malaysian': 'ms-MY',
  };

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await TtsUtils.configureTts(
        flutterTts,
        'en-US',
        speechRate: 0.38,
        pitch: 1.05,
        volume: 1.0,
      );
    } catch (e) {
      print("TTS initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  TranslateLanguage? _getTranslateLanguage(String language) {
    switch (language) {
      case 'English':
        return TranslateLanguage.english;
      case 'Filipino':
        return TranslateLanguage.tagalog;
      case 'Japanese':
        return TranslateLanguage.japanese;
      case 'Korean':
        return TranslateLanguage.korean;
      case 'Chinese':
        return TranslateLanguage.chinese;
      case 'Taiwanese':
        return TranslateLanguage.chinese;
      case 'Singaporean':
        return TranslateLanguage.malay;
      case 'Malaysian':
        return TranslateLanguage.malay;
      default:
        return null;
    }
  }

  Future<void> _translate() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _translateWithMLKit();
    } catch (e) {
      print("ML Kit translation failed: $e");
      try {
        await _translateWithFallback();
      } catch (e) {
        setState(() {
          _errorMessage = 'Translation failed: ${e.toString()}';
          _translatedText = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error translating: ${e.toString()}')),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _translateWithMLKit() async {
    final sourceLang = _getTranslateLanguage(_selectedSourceLanguage);
    final targetLang = _getTranslateLanguage(_selectedTargetLanguage);

    if (sourceLang == null || targetLang == null) {
      throw Exception("Selected language is not supported by ML Kit.");
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );

    try {
      if (!_errorMessage.contains("MissingPluginException")) {
        final modelManager = OnDeviceTranslatorModelManager();

        bool isSourceModelDownloaded =
            await modelManager.isModelDownloaded(sourceLang.bcpCode);
        if (!isSourceModelDownloaded) {
          await modelManager.downloadModel(sourceLang.bcpCode);
        }

        bool isTargetModelDownloaded =
            await modelManager.isModelDownloaded(targetLang.bcpCode);
        if (!isTargetModelDownloaded) {
          await modelManager.downloadModel(targetLang.bcpCode);
        }
      }

      final translatedText =
          await translator.translateText(_textController.text);

      setState(() {
        _translatedText = translatedText;
      });
    } catch (e) {
      if (e.toString().contains("MissingPluginException")) {
        setState(() {
          _errorMessage = "Plugin not available on this device";
        });
      }
      rethrow;
    } finally {
      await translator.close();
    }
  }

  Future<void> _translateWithFallback() async {
    final sourceLanguage = _languageCodes[_selectedSourceLanguage] ?? 'en';
    final targetLanguage = _languageCodes[_selectedTargetLanguage] ?? 'tl';
    final text = _textController.text.trim();

    final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLanguage&tl=$targetLanguage&dt=t&q=${Uri.encodeComponent(text)}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data[0] != null) {
          String translatedText = '';
          for (var sentence in data[0]) {
            if (sentence[0] != null) {
              translatedText += sentence[0];
            }
          }
          setState(() {
            _translatedText = translatedText;
          });
        } else {
          throw Exception("Invalid response format");
        }
      } else {
        throw Exception(
            "API request failed with status: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Fallback translation failed: ${e.toString()}");
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    final languageCode = _ttsLanguageCodes[_selectedTargetLanguage] ?? 'en-US';
    final elevenSuccess = await ElevenLabsTtsService.instance.speak(
      text,
      languageCode: languageCode,
    );
    if (elevenSuccess) return;

    try {
      final normalizedText = TtsUtils.normalizeText(text);

      switch (_selectedTargetLanguage) {
        case 'Chinese':
        case 'Taiwanese':
          await TtsUtils.configureTts(
            flutterTts,
            languageCode,
            speechRate: 0.30,
            pitch: 1.05,
            volume: 0.95,
          );
          break;
        case 'Japanese':
          await TtsUtils.configureTts(
            flutterTts,
            languageCode,
            speechRate: 0.32,
            pitch: 1.05,
            volume: 0.95,
          );
          break;
        case 'Korean':
          await TtsUtils.configureTts(
            flutterTts,
            languageCode,
            speechRate: 0.32,
            pitch: 1.03,
            volume: 0.95,
          );
          break;
        case 'Filipino':
          await TtsUtils.configureTts(
            flutterTts,
            languageCode,
            speechRate: 0.34,
            pitch: 1.02,
            volume: 0.95,
          );
          break;
        case 'English':
          await TtsUtils.configureTts(
            flutterTts,
            languageCode,
            speechRate: 0.34,
            pitch: 1.05,
            volume: 1.0,
          );
          break;
        default:
          await TtsUtils.configureTts(
            flutterTts,
            languageCode,
            speechRate: 0.36,
            pitch: 1.0,
            volume: 0.95,
          );
      }

      await flutterTts.setQueueMode(1);
      await flutterTts.speak(normalizedText);
    } catch (e) {
      print('TTS Error: $e');
      await flutterTts.setLanguage('en-US');
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Human-like voice for $_selectedTargetLanguage not available. Using standard voice instead.')),
        );
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      try {
        final filePath = await _recorder.stop();
        setState(() => _isListening = false);

        if (filePath != null && filePath.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Processing speech with ElevenLabs...'),
                duration: Duration(seconds: 1),
              ),
            );
          }

          final transcript = await ElevenLabsSttService.instance.transcribe(
            File(filePath),
            _languageCodes[_selectedSourceLanguage] ?? 'en-US',
          );

          if (transcript != null && transcript.isNotEmpty) {
            setState(() {
              _textController.text = transcript;
            });
            await _translate();
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ElevenLabs STT failed. Please try again.'),
              ),
            );
          }
        }
      } catch (e) {
        print('Error stopping recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing speech: ${e.toString()}')),
          );
        }
      }
      return;
    }

    try {
      final permissionGranted = await _checkMicPermission();
      if (!permissionGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/elevenlabs_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() => _isListening = true);
    } catch (e) {
      print('Error starting speech recording: $e');
      setState(() => _isListening = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Widget _buildDropdown({
    required String value,
    required String hint,
    required ValueChanged<String?> onChanged,
    required bool isDarkMode,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.blue,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        items: _buildDropdownItems(),
        onChanged: onChanged,
        dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          color: isDarkMode ? const Color(0xFF4080FF) : Colors.blue,
          size: 20,
        ),
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? const Color(0xFFE0E0E0) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isListening ? 36 : 32,
      height: _isListening ? 36 : 32,
      decoration: BoxDecoration(
        color: _isListening
            ? (isDarkMode
                ? const Color(0xFFFFB74D)
                : Theme.of(context).colorScheme.tertiary)
            : (isDarkMode
                ? const Color(0xFF4080FF)
                : Theme.of(context).colorScheme.primary),
        shape: BoxShape.circle,
        boxShadow: _isListening
            ? [
                BoxShadow(
                  color: (isDarkMode
                          ? const Color(0xFFFFB74D)
                          : Theme.of(context).colorScheme.tertiary)
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleListening,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: _isListening ? 18 : 16,
                key: ValueKey<bool>(_isListening),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ElevatedButton _buildTranslateButton() {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _translate,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.translate, size: 16, key: ValueKey('translate')),
      ),
      label: const Text('Translate', style: TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4080FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        disabledBackgroundColor: isDarkMode
            ? const Color(0xFF4080FF).withValues(alpha: 0.3)
            : Colors.blue.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildTranslatedResult() {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    if (_translatedText.isEmpty) return const SizedBox();

    return Card(
      elevation: isDarkMode ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Translation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? const Color(0xFF4080FF) : Colors.blue,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy,
                          color: isDarkMode
                              ? const Color(0xFF4080FF)
                              : Colors.blue,
                          size: 20),
                      onPressed: () => _copyToClipboard(_translatedText),
                      tooltip: 'Copy to clipboard',
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(Icons.volume_up,
                          color: isDarkMode
                              ? const Color(0xFF4080FF)
                              : Colors.blue,
                          size: 20),
                      onPressed: () => _speak(_translatedText),
                      tooltip: 'Listen',
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF3D3D3D)
                      : Colors.grey.shade200,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _translatedText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDarkMode
                        ? const Color(0xFFE0E0E0)
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    if (_errorMessage.isEmpty) return const SizedBox();

    return Card(
      elevation: isDarkMode ? 1 : 3,
      color: isDarkMode ? const Color(0xFF3A2027) : Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: isDarkMode
                    ? const Color(0xFFCF6679)
                    : Colors.red.shade700,
                size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFCF6679)
                      : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkMicPermission() async {
    try {
      var micStatus = await Permission.microphone.status;
      if (micStatus.isDenied) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) return false;
      }
      if (Platform.isIOS) {
        var speechStatus = await Permission.speech.status;
        if (speechStatus.isDenied) {
          speechStatus = await Permission.speech.request();
          if (!speechStatus.isGranted) return false;
        }
      }
      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('voice_translator'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? const Color(0xFFE0E0E0) : Colors.blue,
          ),
        ),
        elevation: isDarkMode ? 0 : 2,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: DarkModeToggle(showLabel: false, isMini: true),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Language Selection
                  Card(
                    elevation: isDarkMode ? 1 : 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDarkMode
                                      ? const Color(0xFF3D3D3D)
                                      : Colors.blue.withValues(alpha: 0.5),
                                ),
                                color: isDarkMode
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                              ),
                              child: _buildDropdown(
                                value: _selectedSourceLanguage,
                                hint: AppLocalizations.of(context).translate('from'),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedSourceLanguage = value);
                                  }
                                },
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFFFFB74D)
                                  : const Color(0xFFFFB300),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.swap_horiz,
                                  color: Colors.white, size: 20),
                              onPressed: () {
                                setState(() {
                                  final temp = _selectedSourceLanguage;
                                  _selectedSourceLanguage =
                                      _selectedTargetLanguage;
                                  _selectedTargetLanguage = temp;
                                });
                              },
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDarkMode
                                      ? const Color(0xFF3D3D3D)
                                      : Colors.blue.withValues(alpha: 0.5),
                                ),
                                color: isDarkMode
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                              ),
                              child: _buildDropdown(
                                value: _selectedTargetLanguage,
                                hint: AppLocalizations.of(context).translate('to'),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedTargetLanguage = value);
                                  }
                                },
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Input Area
                  Card(
                    elevation: isDarkMode ? 1 : 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppLocalizations.of(context)
                                    .translate('enter_text'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? const Color(0xFFE0E0E0)
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 80,
                            child: TextField(
                              controller: _textController,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context).translate(
                                    'type_or_speak_text_to_translate'),
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? const Color(0xFF909090)
                                      : Colors.grey.shade600,
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? const Color(0xFF3D3D3D)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? const Color(0xFF4080FF)
                                        : Colors.blue,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDarkMode
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.grey.shade50,
                                contentPadding: const EdgeInsets.all(8),
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? const Color(0xFFE0E0E0)
                                    : Colors.black87,
                              ),
                              maxLines: 4,
                              minLines: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildTranslateButton()),
                              const SizedBox(width: 10),
                              _buildMicButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildErrorMessage(),
                  if (_errorMessage.isNotEmpty) const SizedBox(height: 12),
                  _buildTranslatedResult(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}