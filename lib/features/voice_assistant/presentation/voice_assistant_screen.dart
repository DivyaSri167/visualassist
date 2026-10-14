import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../camera/data/camera_providers.dart';
import '../../device_connection/data/device_providers.dart';
import '../../object_detection/data/object_detection_providers.dart';
import '../../object_detection/data/yolo_config.dart';
import '../../safety/data/safety_providers.dart';
import '../../scene_understanding/data/scene_providers.dart';
import '../../text_reader/data/ocr_providers.dart';
import '../data/conversational_memory.dart';
import '../data/vlm_service.dart';
import '../data/voice_query_engine.dart';
import '../domain/conversation_message.dart';

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  static const Color _cardBorderColor = Color(0xFF334155);

  final TextEditingController _testTextController = TextEditingController(
    text: 'Caution: chair ahead center zone.',
  );
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  final List<({VoiceIntent intent, String query, String answer})> _queryHistory = [];
  final ConversationalMemory _memory = ConversationalMemory();
  final VlmService _vlmService = VlmService();

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isProcessingAi = false;
  bool _isConversationalMode = true; // Auto-listen for follow-up turns
  String _selectedLanguage = 'en'; // 'en', 'ta', 'tanglish'
  String? _configuredApiKey;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadVlmApiKey();
  }

  Future<void> _loadVlmApiKey() async {
    final key = await _vlmService.getApiKey();
    if (mounted) {
      setState(() {
        _configuredApiKey = key;
        if (key != null) _apiKeyController.text = key;
      });
    }
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  String _getLocaleId() {
    switch (_selectedLanguage) {
      case 'ta':
        return 'ta_IN';
      case 'tanglish':
        return 'en_IN';
      default:
        return 'en_US';
    }
  }

  void _startListening(dynamic speechEngine) async {
    if (!_speechEnabled) {
      _initSpeech();
    }
    // Stop any active TTS audio before listening to avoid microphone feedback
    speechEngine.stop();
    setState(() => _isListening = true);

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _queryController.text = result.recognizedWords;
            if (result.finalResult) {
              setState(() => _isListening = false);
              _handleQuery(result.recognizedWords, speechEngine);
            }
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _getLocaleId(),
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      setState(() => _isListening = false);
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  void _interruptAll(dynamic speechEngine) {
    speechEngine.stop();
    _stopListening();
    setState(() {
      _isProcessingAi = false;
    });
  }

  @override
  void dispose() {
    _speechToText.stop();
    _vlmService.dispose();
    _testTextController.dispose();
    _queryController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speechEngine = ref.watch(speechEngineProvider);
    final yoloConfig = ref.watch(yoloConfigProvider);
    final stepState = ref.watch(userStepStateProvider).value;

    // Register callback for continuous multi-turn conversational loop
    speechEngine.onSpeechComplete = () {
      if (_isConversationalMode && mounted && !_isListening && !_isProcessingAi && !speechEngine.isSpeaking) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _isConversationalMode && !_isListening && !_isProcessingAi && !speechEngine.isSpeaking) {
            _startListening(speechEngine);
          }
        });
      }
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        actions: [
          IconButton(
            tooltip: 'Configure Gemini VLM API Key',
            icon: Icon(
              Icons.vpn_key,
              color: _configuredApiKey != null && _configuredApiKey!.isNotEmpty
                  ? AppTheme.accentCyan
                  : AppTheme.secondaryText,
            ),
            onPressed: () => _showApiKeyDialog(),
          ),
          IconButton(
            tooltip: speechEngine.isMuted ? 'Unmute speech' : 'Mute speech',
            icon: Icon(
              speechEngine.isMuted ? Icons.volume_off : Icons.volume_up,
              color: speechEngine.isMuted ? AppTheme.errorRed : AppTheme.primaryAmber,
            ),
            onPressed: () {
              setState(() {
                speechEngine.toggleMute();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Banner
            _buildStatusHeader(speechEngine, yoloConfig),

            const SizedBox(height: 16),

            // Continuous Conversation & Language Control Card
            _buildConversationModeCard(speechEngine),

            const SizedBox(height: 16),

            // Natural Language Query Input & Voice Microphone
            _buildQueryCard(speechEngine),

            const SizedBox(height: 16),

            // Mode & Engine Configuration Card
            _buildEngineSettingsCard(speechEngine, yoloConfig),

            const SizedBox(height: 16),

            // Direct TTS Tester
            _buildDirectSpeakCard(speechEngine),

            const SizedBox(height: 16),

            // Quick Accessibility Presets
            _buildQuickPresetsCard(speechEngine, stepState?.sessionSteps ?? 0),

            const SizedBox(height: 16),

            // Help & Bluetooth Guidance
            _buildBluetoothGuidanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(dynamic speechEngine, YoloConfig yoloConfig) {
    final isMuted = speechEngine.isMuted;
    final isPaused = speechEngine.isPaused;
    final isSpeaking = speechEngine.isSpeaking;

    String statusText;
    Color statusColor;

    if (isMuted) {
      statusText = 'Muted';
      statusColor = AppTheme.errorRed;
    } else if (isPaused) {
      statusText = 'Paused';
      statusColor = AppTheme.warningOrange;
    } else if (_isProcessingAi) {
      statusText = 'AI Thinking…';
      statusColor = AppTheme.accentCyan;
    } else if (isSpeaking) {
      statusText = 'Speaking Now';
      statusColor = AppTheme.successGreen;
    } else if (_isListening) {
      statusText = 'Listening…';
      statusColor = AppTheme.errorRed;
    } else {
      statusText = 'Ready (Idle)';
      statusColor = AppTheme.primaryAmber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.record_voice_over, color: AppTheme.primaryAmber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Speech Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.highContrastText,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Mode: ${yoloConfig.announcementMode.displayName}',
            style: const TextStyle(fontSize: 14, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 4),
          Text(
            'Cooldown: ${yoloConfig.announcementCooldownSeconds}s between repeat alerts',
            style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AccessibleButton(
                  label: isMuted ? 'Unmute' : 'Mute',
                  icon: isMuted ? Icons.volume_off : Icons.volume_up,
                  isPrimary: false,
                  customColor: isMuted ? AppTheme.darkSurface : _cardBorderColor,
                  customTextColor: isMuted ? AppTheme.errorRed : AppTheme.highContrastText,
                  onPressed: () {
                    setState(() {
                      speechEngine.toggleMute();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AccessibleButton(
                  label: isPaused ? 'Resume' : 'Pause',
                  icon: isPaused ? Icons.play_arrow : Icons.pause,
                  isPrimary: false,
                  customColor: _cardBorderColor,
                  customTextColor: AppTheme.highContrastText,
                  onPressed: () {
                    setState(() {
                      if (isPaused) {
                        speechEngine.resume();
                      } else {
                        speechEngine.pause();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AccessibleButton(
                  label: 'Stop Speech',
                  icon: Icons.stop,
                  isPrimary: isSpeaking || _isListening,
                  customColor: isSpeaking || _isListening ? AppTheme.errorRed : _cardBorderColor,
                  customTextColor: isSpeaking || _isListening ? Colors.white : AppTheme.secondaryText,
                  onPressed: () => _interruptAll(speechEngine),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationModeCard(dynamic speechEngine) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.forum, color: AppTheme.primaryAmber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Multi-Turn Conversation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.highContrastText,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isConversationalMode,
                activeThumbColor: AppTheme.primaryAmber,
                onChanged: (val) {
                  setState(() => _isConversationalMode = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isConversationalMode
                ? 'Continuous listening active. The assistant will listen automatically after speaking.'
                : 'Manual tap-to-talk. Tap the microphone button for each question.',
            style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          const Divider(color: _cardBorderColor, height: 1),
          const SizedBox(height: 12),
          const Text(
            'Language / மொழி',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.highContrastText),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLangChoiceChip('English', 'en', speechEngine),
              const SizedBox(width: 8),
              _buildLangChoiceChip('தமிழ் (Tamil)', 'ta', speechEngine),
              const SizedBox(width: 8),
              _buildLangChoiceChip('Tanglish', 'tanglish', speechEngine),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangChoiceChip(String label, String code, dynamic speechEngine) {
    final isSelected = _selectedLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryAmber,
      backgroundColor: _cardBorderColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.highContrastText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedLanguage = code);
          final ttsCode = code == 'ta' ? 'ta-IN' : 'en-US';
          speechEngine.setLanguage(ttsCode);
        }
      },
    );
  }

  void _handleQuery(String query, dynamic speechEngine) async {
    final q = query.trim();
    if (q.isEmpty) return;

    final intent = VoiceQueryEngine.matchIntent(q);

    // 1. Immediate interrupt / Stop
    if (intent == VoiceIntent.stopSpeech) {
      _interruptAll(speechEngine);
      return;
    }

    // 2. Emergency SOS
    if (intent == VoiceIntent.emergency) {
      _stopListening();
      final msg = VoiceQueryEngine.isTamilQuery(q)
          ? 'அவசர உதவி கோரப்பட்டுள்ளது. உதவி எச்சரிக்கை செயல்படுத்தப்படுகிறது.'
          : 'Emergency requested. Triggering safety alert escalation.';
      speechEngine.speakDirect(msg);
      ref.read(safetyProvider.notifier).triggerManualSos();
      return;
    }

    // 3. OCR Text Reading
    if (intent == VoiceIntent.readText) {
      _stopListening();
      final msg = VoiceQueryEngine.isTamilQuery(q)
          ? 'பலகை மற்றும் எழுத்துக்களை வாசிக்க கேமரா படம் எடுக்கப்படுகிறது.'
          : 'Capturing camera frame to read visible text aloud.';
      speechEngine.speakDirect(msg);
      ref.read(ocrProvider.notifier).captureAndRead();
      return;
    }

    setState(() {
      _isProcessingAi = true;
    });

    final stepState = ref.read(userStepStateProvider).value;
    final connectionState = ref.read(deviceConnectionProvider);
    final sceneState = ref.read(sceneUnderstandingProvider);
    final streamState = ref.read(cameraStreamServiceProvider).currentState;
    final pipeline = ref.read(pipelineStateProvider);

    final detections = pipeline.currentDetections.isNotEmpty
        ? pipeline.currentDetections
        : sceneState.detections;

    String answer = '';
    List<String> referencedObjects = [];

    // 4. Visual Surroundings & VLM Question Answering
    final isVisualQuery = intent == VoiceIntent.describeScene ||
        intent == VoiceIntent.checkPath ||
        intent == VoiceIntent.whereAmI ||
        intent == VoiceIntent.objectDetails ||
        intent == VoiceIntent.personNearby ||
        intent == VoiceIntent.objectsOnLeft ||
        intent == VoiceIntent.objectsOnRight;

    if (isVisualQuery) {
      // Proactive feedback for visual reasoning if taking time
      final isTamil = VoiceQueryEngine.isTamilQuery(q) || _selectedLanguage == 'ta';
      if (_configuredApiKey != null && _configuredApiKey!.isNotEmpty) {
        speechEngine.speakDirect(isTamil ? 'ஒரு நிமிடம் காத்திருங்கள், சரிபார்க்கிறேன்.' : 'Please wait while I check that.');
      }

      final Uint8List? frame = streamState.currentFrame?.bytes;

      answer = await _vlmService.answerVisualQuestion(
        query: q,
        imageBytes: frame,
        currentDetections: detections,
        memory: _memory,
        preferredLanguage: _selectedLanguage,
      );

      referencedObjects = detections.map((d) => d.label).toList();
    } else {
      // 5. Rule-Based Grounded Voice Engine
      final result = VoiceQueryEngine.generateAnswer(
        intent: intent,
        query: q,
        memory: _memory,
        sessionSteps: stepState?.sessionSteps ?? 0,
        estimatedDistanceMeters: (stepState?.sessionSteps ?? 0) * 0.7,
        isConnected: connectionState.isConnected,
        cameraFps: streamState.fps,
        sceneSummary: sceneState.narration,
        environmentName: sceneState.synthesis?.environment.displayName,
        pathClearanceText: sceneState.synthesis?.clearance.description,
        detections: detections,
      );
      answer = result.answer;
      referencedObjects = result.referencedObjects;
    }

    // Record turn in conversational memory
    _memory.recordTurn(
      speaker: MessageSpeaker.user,
      text: q,
      intent: intent,
      referencedObjects: referencedObjects,
      language: _selectedLanguage,
    );
    _memory.recordTurn(
      speaker: MessageSpeaker.assistant,
      text: answer,
      intent: intent,
      referencedObjects: referencedObjects,
      language: _selectedLanguage,
    );

    if (mounted) {
      setState(() {
        _isProcessingAi = false;
        _queryHistory.insert(0, (intent: intent, query: q, answer: answer));
        if (_queryHistory.length > 8) _queryHistory.removeLast();
      });
      _queryController.clear();
    }

    // Speak answer aloud to the blind user
    speechEngine.speakDirect(answer);
  }

  Widget _buildQueryCard(dynamic speechEngine) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryAmber, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'Natural Language Voice Assistant',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.highContrastText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ask questions using your voice about your surroundings, text, obstacles, or walking stats.',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 14),
          // Prominent Accessible Microphone Voice Button
          AccessibleButton(
            label: _isListening
                ? 'Listening… Tap to Stop'
                : (_isProcessingAi ? 'AI Processing…' : 'Tap to Speak (Voice Command)'),
            icon: _isListening ? Icons.mic : (_isProcessingAi ? Icons.hourglass_top : Icons.mic_none),
            isPrimary: _isListening,
            customColor: _isListening
                ? AppTheme.errorRed
                : (_isProcessingAi ? AppTheme.accentCyan : AppTheme.primaryAmber),
            customTextColor: Colors.black,
            semanticHint: 'Activates microphone for hands-free voice questions',
            onPressed: () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening(speechEngine);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(color: AppTheme.highContrastText),
                  onSubmitted: (v) => _handleQuery(v, speechEngine),
                  decoration: InputDecoration(
                    hintText: 'e.g. "What is in front of me?"',
                    hintStyle: const TextStyle(color: AppTheme.secondaryText),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryAmber),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.send, color: Colors.black, size: 20),
                tooltip: 'Submit query',
                onPressed: () => _handleQuery(_queryController.text, speechEngine),
              ),
            ],
          ),
          // Query quick hints
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _QueryChip(label: 'What is in front of me?', onTap: () => _handleQuery('What is in front of me?', speechEngine)),
              _QueryChip(label: 'What is written on this board?', onTap: () => _handleQuery('What is written on this board?', speechEngine)),
              _QueryChip(label: 'Is there a person near me?', onTap: () => _handleQuery('Is there a person near me?', speechEngine)),
              _QueryChip(label: 'What objects on my left?', onTap: () => _handleQuery('What objects are on my left?', speechEngine)),
              _QueryChip(label: 'Describe my surroundings', onTap: () => _handleQuery('Describe my surroundings.', speechEngine)),
              _QueryChip(label: 'Is path clear?', onTap: () => _handleQuery('Can I walk ahead?', speechEngine)),
              _QueryChip(label: 'Step count', onTap: () => _handleQuery('How many steps?', speechEngine)),
              _QueryChip(label: 'முன்னாடி என்ன இருக்கு?', onTap: () => _handleQuery('முன்னாடி என்ன இருக்கு?', speechEngine)),
              _QueryChip(label: 'எழுத்துக்களை படி', onTap: () => _handleQuery('எழுத்துக்களை படி', speechEngine)),
            ],
          ),
          // Recent query history with answers
          if (_queryHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),
            const Text(
              'Recent Dialogue / உரையாடல்',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.highContrastText),
            ),
            const SizedBox(height: 8),
            ..._queryHistory.take(4).map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_intentIcon(item.intent), size: 14, color: AppTheme.primaryAmber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'You: "${item.query}"',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.highContrastText),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x2238BDF8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.intent.title,
                            style: const TextStyle(fontSize: 9, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI: ${item.answer}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Google Gemini VLM API Key', style: TextStyle(color: AppTheme.highContrastText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter an optional Gemini API key to enable Cloud Vision-Language reasoning. Leave empty to use 100% offline on-device AI.',
                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                style: const TextStyle(color: AppTheme.highContrastText),
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: const TextStyle(color: AppTheme.secondaryText),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAmber),
              onPressed: () async {
                final key = _apiKeyController.text.trim();
                await _vlmService.setApiKey(key.isEmpty ? null : key);
                setState(() => _configuredApiKey = key.isEmpty ? null : key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Key', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  IconData _intentIcon(VoiceIntent intent) {
    switch (intent) {
      case VoiceIntent.describeScene: return Icons.visibility;
      case VoiceIntent.readText: return Icons.text_fields;
      case VoiceIntent.checkPath: return Icons.straight;
      case VoiceIntent.personNearby: return Icons.person;
      case VoiceIntent.objectsOnLeft: return Icons.arrow_back;
      case VoiceIntent.objectsOnRight: return Icons.arrow_forward;
      case VoiceIntent.objectDetails: return Icons.info_outline;
      case VoiceIntent.whereAmI: return Icons.place;
      case VoiceIntent.stepCount: return Icons.directions_walk;
      case VoiceIntent.location: return Icons.my_location;
      case VoiceIntent.emergency: return Icons.emergency;
      case VoiceIntent.deviceStatus: return Icons.wifi;
      case VoiceIntent.stopSpeech: return Icons.stop;
      case VoiceIntent.help: return Icons.help_outline;
      case VoiceIntent.generalKnowledge: return Icons.lightbulb_outline;
      case VoiceIntent.unknown: return Icons.help_outline;
    }
  }

  Widget _buildEngineSettingsCard(dynamic speechEngine, YoloConfig yoloConfig) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engine Preferences',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.highContrastText,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppTheme.primaryAmber,
              title: const Text(
                'Announce Camera Obstacles',
                style: TextStyle(color: AppTheme.highContrastText),
              ),
              subtitle: const Text(
                'Enables automatic object & hazard descriptions',
                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
              value: yoloConfig.speechEnabled,
              onChanged: (_) {
                ref.read(yoloConfigProvider.notifier).toggleSpeech();
              },
            ),
          ),
          const Divider(color: _cardBorderColor),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cadence / Speech Rate',
                style: TextStyle(color: AppTheme.highContrastText, fontSize: 14),
              ),
              Text(
                '0.52 (Natural)',
                style: TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Optimized for rapid comprehension over Bluetooth earpieces.',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectSpeakCard(dynamic speechEngine) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Speak on Demand',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.highContrastText,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _testTextController,
            style: const TextStyle(color: AppTheme.highContrastText),
            decoration: InputDecoration(
              hintText: 'Enter text to vocalize...',
              hintStyle: const TextStyle(color: AppTheme.secondaryText),
              filled: true,
              fillColor: AppTheme.darkBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _cardBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryAmber),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AccessibleButton(
            label: 'Speak Now',
            icon: Icons.volume_up,
            isPrimary: true,
            customColor: AppTheme.primaryAmber,
            customTextColor: Colors.black,
            onPressed: () {
              final text = _testTextController.text.trim();
              if (text.isNotEmpty) {
                speechEngine.speakDirect(text);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetsCard(dynamic speechEngine, int estimatedSteps) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accessibility Audio Presets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.highContrastText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.directions_walk, size: 16, color: AppTheme.primaryAmber),
                label: const Text('Step Count', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  speechEngine.speakDirect(
                    'You have taken approximately $estimatedSteps steps. This is an estimate, not a verified step count.',
                  );
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.warning, size: 16, color: AppTheme.errorRed),
                label: const Text('Hazard Alert', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  speechEngine.speakDirect('Urgent warning: stairs approaching in center path.');
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.arrow_back, size: 16, color: AppTheme.primaryAmber),
                label: const Text('Left Zone', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  speechEngine.speakDirect('Pedestrian detected on left.');
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.arrow_forward, size: 16, color: AppTheme.primaryAmber),
                label: const Text('Right Zone', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  speechEngine.speakDirect('Bicycle detected on right.');
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.check_circle, size: 16, color: AppTheme.successGreen),
                label: const Text('Path Clear', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  speechEngine.speakDirect('Walking path is currently clear.');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth_audio, color: AppTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'Bluetooth Earphone Guidance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.highContrastText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Connect bone-conduction or open-ear Bluetooth headphones via Android system settings.\n'
            '• Open-ear design ensures ambient environmental awareness is preserved.\n'
            '• Audio output automatically routes through the active Bluetooth device.\n'
            '• Low-latency directional speech announces upcoming obstacles before contact.',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _QueryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QueryChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.secondaryText,
          ),
        ),
      ),
    );
  }
}
