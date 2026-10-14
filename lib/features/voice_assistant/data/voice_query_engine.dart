
/// Semantic intent recognized from verbal or typed user queries.
enum VoiceIntent {
  describeScene('Describe Scene', 'Perceives and describes the current surroundings'),
  readText('Read Text / OCR', 'Captures camera snapshot and reads text aloud'),
  checkPath('Check Path Ahead', 'Checks center walking path for immediate obstacles'),
  whereAmI('Where Am I?', 'Identifies environmental room context'),
  stepCount('Step Count & Distance', 'Reports pedometer count and walking distance'),
  deviceStatus('Hardware & Link Status', 'Reports ESP32-CAM connection and frame rate'),
  stopSpeech('Stop Audio', 'Halts speech playback immediately'),
  help('Help & Voice Commands', 'Lists available voice capabilities'),
  unknown('General Query', 'Unrecognized inquiry');

  final String title;
  final String description;
  const VoiceIntent(this.title, this.description);
}

/// Result of processing a voice query.
class VoiceQueryResult {
  final String originalQuery;
  final VoiceIntent intent;
  final String answer;
  final DateTime timestamp;

  const VoiceQueryResult({
    required this.originalQuery,
    required this.intent,
    required this.answer,
    required this.timestamp,
  });
}

/// Resolves user natural-language queries into assistive action intents and spoken responses.
class VoiceQueryEngine {
  /// Analyzes query string [input] and identifies the best matching [VoiceIntent].
  static VoiceIntent matchIntent(String input) {
    final text = input.trim().toLowerCase();

    if (text.isEmpty) return VoiceIntent.unknown;

    // 1. Stop / Silence commands
    if (text == 'stop' ||
        text == 'quiet' ||
        text == 'silence' ||
        text.contains('stop speaking') ||
        text.contains('shut up') ||
        text.contains('be quiet')) {
      return VoiceIntent.stopSpeech;
    }

    // 2. OCR & Text Reading
    if (text.contains('read') ||
        text.contains('text') ||
        text.contains('ocr') ||
        text.contains('sign') ||
        text.contains('menu') ||
        text.contains('what does it say') ||
        text.contains('what is written')) {
      return VoiceIntent.readText;
    }

    // 3. Path Clearance & Obstacle Inquiry
    if (text.contains('path') ||
        text.contains('obstacle') ||
        text.contains('clear') ||
        text.contains('can i walk') ||
        text.contains('safe to walk') ||
        text.contains('in my way') ||
        text.contains('in the way') ||
        text.contains('walk ahead')) {
      return VoiceIntent.checkPath;
    }

    // 4. Where Am I / Environmental Context
    if (text.contains('where am i') ||
        text.contains('which room') ||
        text.contains('what room') ||
        text.contains('environment') ||
        text.contains('surrounding') ||
        text.contains('location') ||
        text.contains('place')) {
      return VoiceIntent.whereAmI;
    }

    // 5. Scene Understanding / General Visual Description
    if (text.contains('describe') ||
        text.contains('what is in front') ||
        text.contains('what is ahead') ||
        text.contains('what do you see') ||
        text.contains('look around') ||
        text.contains('see ahead') ||
        text.contains('scene')) {
      return VoiceIntent.describeScene;
    }

    // 6. Step Count / Walking Stats
    if (text.contains('step') ||
        text.contains('distance') ||
        text.contains('walked') ||
        text.contains('pace') ||
        text.contains('cadence') ||
        text.contains('footstep')) {
      return VoiceIntent.stepCount;
    }

    // 7. Device Status / Battery / WiFi
    if (text.contains('status') ||
        text.contains('battery') ||
        text.contains('connection') ||
        text.contains('connected') ||
        text.contains('camera') ||
        text.contains('fps') ||
        text.contains('wifi') ||
        text.contains('wi-fi') ||
        text.contains('link')) {
      return VoiceIntent.deviceStatus;
    }

    // 8. Help & Command Guide
    if (text.contains('help') ||
        text.contains('command') ||
        text.contains('what can you do') ||
        text.contains('options')) {
      return VoiceIntent.help;
    }

    return VoiceIntent.unknown;
  }

  /// Synthesizes an assistive spoken answer for the given intent.
  static String generateAnswer({
    required VoiceIntent intent,
    required String query,
    int sessionSteps = 0,
    double estimatedDistanceMeters = 0.0,
    bool isConnected = false,
    double cameraFps = 0.0,
    String? sceneSummary,
    String? pathClearanceText,
    String? environmentName,
  }) {
    switch (intent) {
      case VoiceIntent.stopSpeech:
        return 'Speech halted.';

      case VoiceIntent.checkPath:
        if (pathClearanceText != null && pathClearanceText.isNotEmpty) {
          return pathClearanceText;
        }
        return 'Analyzing walking path. Hold steady while verifying center corridor.';

      case VoiceIntent.describeScene:
        if (sceneSummary != null && sceneSummary.isNotEmpty) {
          return sceneSummary;
        }
        return 'Starting full environmental scan. Looking for objects ahead.';

      case VoiceIntent.readText:
        return 'Capturing camera frame to read visible text aloud.';

      case VoiceIntent.whereAmI:
        if (environmentName != null && environmentName.isNotEmpty) {
          return 'You appear to be in an $environmentName.';
        }
        return 'Scanning surroundings to determine environmental context.';

      case VoiceIntent.stepCount:
        final km = (estimatedDistanceMeters / 1000).toStringAsFixed(2);
        return 'You have taken $sessionSteps steps, covering approximately $km kilometers.';

      case VoiceIntent.deviceStatus:
        if (isConnected) {
          final fpsText = cameraFps > 0
              ? ' Video stream is running smoothly at ${cameraFps.toStringAsFixed(1)} frames per second.'
              : '';
          return 'ESP32-CAM Smart-Cap is connected and operational.$fpsText';
        } else {
          return 'ESP32-CAM is currently disconnected. Please verify Wi-Fi link to VisionAssist-Cap.';
        }

      case VoiceIntent.help:
        return 'You can ask: "What is ahead?", "Read text", "Is my path clear?", "Where am I?", "How many steps?", or "Check status".';

      case VoiceIntent.unknown:
        return 'I did not recognize that command. You can ask "What is in front of me?", "Read text", "Check path", or "Step count".';
    }
  }
}
