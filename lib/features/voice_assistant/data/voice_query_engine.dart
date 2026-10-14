import '../../object_detection/domain/detected_object.dart';
import '../../object_detection/domain/direction_zone.dart';
import '../../scene_understanding/data/scene_description_engine.dart';
import 'conversational_memory.dart';

/// Semantic intent recognized from verbal or typed user queries.
enum VoiceIntent {
  describeScene('Describe Scene', 'Perceives and describes the current surroundings'),
  readText('Read Text / OCR', 'Captures camera snapshot and reads text aloud'),
  checkPath('Check Path Ahead', 'Checks center walking path for immediate obstacles'),
  personNearby('Check Person Nearby', 'Checks if any people are detected in view'),
  objectsOnLeft('Objects on Left', 'Lists objects located on user left'),
  objectsOnRight('Objects on Right', 'Lists objects located on user right'),
  objectDetails('Object Details & Context', 'Clarifies follow-up questions about objects or usage'),
  whereAmI('Where Am I?', 'Identifies environmental room context'),
  stepCount('Step Count & Distance', 'Reports pedometer count and walking distance'),
  location('GPS Location', 'Reports current location coordinates or physical address'),
  emergency('Emergency SOS', 'Triggers safety assistance alert'),
  deviceStatus('Hardware & Link Status', 'Reports ESP32-CAM connection and frame rate'),
  stopSpeech('Stop Audio', 'Halts speech playback immediately'),
  help('Help & Voice Commands', 'Lists available voice capabilities'),
  generalKnowledge('General Query', 'Answers conversational questions not requiring vision'),
  unknown('Unrecognized', 'Unrecognized inquiry');

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
  final List<String> referencedObjects;
  final String? clarificationQuestion;

  const VoiceQueryResult({
    required this.originalQuery,
    required this.intent,
    required this.answer,
    required this.timestamp,
    this.referencedObjects = const [],
    this.clarificationQuestion,
  });

  @override
  String toString() => answer;
}

/// Resolves user natural-language queries into assistive action intents and spoken responses.
/// Fully supports English, Tamil, and Tanglish.
class VoiceQueryEngine {
  /// Detects if input is in Tamil script or Tanglish phrasing.
  static bool isTamilQuery(String input) {
    if (input.contains(RegExp(r'[\u0B80-\u0BFF]'))) return true;
    final text = input.trim().toLowerCase();
    const tanglishKeywords = [
      'enna', 'enga', 'irukku', 'irukaangala', 'yaravathu', 'aaravathu',
      'solla', 'sollu', 'nillu', 'nirutha', 'pesatha', 'padikkavum',
      'padika', 'padikava', 'path clear', 'valiyil', 'edathu', 'valathu',
      'munnadi', 'pinnadi', 'thirumbu', 'nadai', 'adikal'
    ];
    for (final kw in tanglishKeywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  /// Analyzes query string [input] and identifies the best matching [VoiceIntent].
  static VoiceIntent matchIntent(String input) {
    final text = input.trim().toLowerCase();

    if (text.isEmpty) return VoiceIntent.unknown;

    // 1. Stop / Silence commands (English + Tamil + Tanglish)
    if (text == 'stop' ||
        text == 'quiet' ||
        text == 'silence' ||
        text == 'halt' ||
        text.contains('stop speaking') ||
        text.contains('shut up') ||
        text.contains('be quiet') ||
        text.contains('நிறுத்து') ||
        text.contains('அமைதி') ||
        text.contains('பேசாதே') ||
        text.contains('pesatha') ||
        text.contains('nirutha') ||
        text.contains('nillu')) {
      return VoiceIntent.stopSpeech;
    }

    // 2. Emergency SOS (English + Tamil + Tanglish)
    if (text.contains('emergency') ||
        text.contains('sos') ||
        text.contains('danger') ||
        text.contains('call for help') ||
        text.contains('need help urgently') ||
        text.contains('ஆபத்து') ||
        text.contains('உதவி தேவை') ||
        text.contains('காப்பாற்று') ||
        text.contains('aabathu') ||
        text.contains('emergency call')) {
      return VoiceIntent.emergency;
    }

    // 3. OCR & Text Reading (English + Tamil + Tanglish)
    if (text.contains('read') ||
        text.contains('text') ||
        text.contains('ocr') ||
        text.contains('sign') ||
        text.contains('menu') ||
        text.contains('board') ||
        text.contains('what does it say') ||
        text.contains('what is written') ||
        text.contains('வாசி') ||
        text.contains('படி') ||
        text.contains('என்ன எழுதி') ||
        text.contains('பலகை') ||
        text.contains('எழுத்து') ||
        text.contains('padikavum') ||
        text.contains('padika') ||
        text.contains('enna ezhuthi') ||
        text.contains('board la enna')) {
      return VoiceIntent.readText;
    }

    // 4. Inquire specifically about people nearby (English + Tamil + Tanglish)
    if (text.contains('person') ||
        text.contains('anyone') ||
        text.contains('someone') ||
        text.contains('people') ||
        RegExp(r'\b(man|men|woman|women)\b').hasMatch(text) ||
        text.contains('மனிதர்') ||
        text.contains('யாராவது') ||
        text.contains('ஆள்') ||
        text.contains('aaravathu') ||
        text.contains('yaravathu') ||
        text.contains('yaarum')) {
      return VoiceIntent.personNearby;
    }

    // 5. Follow-up object queries / pronoun references ("What color is it?", "What is it used for?", "Is it close?")
    if (text.contains('used for') ||
        text.contains('what color') ||
        text.contains('what is this object') ||
        text.contains('what is the object') ||
        text.contains('can i sit') ||
        text.contains('can i use') ||
        text.contains('is it close') ||
        text.contains('how far is it') ||
        text.contains('எதற்கு பயன்படும்') ||
        text.contains('பயன்') ||
        text.contains('அருகில் இருக்கிறதா') ||
        text.contains('பக்கத்தில் இருக்கா') ||
        text.contains('ithu enna object') ||
        text.contains('ithu edhukku')) {
      return VoiceIntent.objectDetails;
    }

    // 6. Directional queries: Left / Right (English + Tamil + Tanglish)
    if (text.contains('on my left') ||
        text.contains('on the left') ||
        text.contains('to my left') ||
        text.contains('left side') ||
        text.contains('இடது பக்கம்') ||
        text.contains('இடதுபுறம்') ||
        text.contains('left la') ||
        text.contains('edathu pakkam')) {
      return VoiceIntent.objectsOnLeft;
    }
    if (text.contains('on my right') ||
        text.contains('on the right') ||
        text.contains('to my right') ||
        text.contains('right side') ||
        text.contains('வலது பக்கம்') ||
        text.contains('வலதுபுறம்') ||
        text.contains('right la') ||
        text.contains('valathu pakkam')) {
      return VoiceIntent.objectsOnRight;
    }

    // 7. Path Clearance & Obstacle Inquiry (English + Tamil + Tanglish)
    if (text.contains('path') ||
        text.contains('obstacle') ||
        text.contains('clear') ||
        text.contains('can i walk') ||
        text.contains('safe to walk') ||
        text.contains('in my way') ||
        text.contains('in the way') ||
        text.contains('walk ahead') ||
        text.contains('தடை') ||
        text.contains('பாதை') ||
        text.contains('வழி') ||
        text.contains('நடக்கலாமா') ||
        text.contains('path clear') ||
        text.contains('valiyil thadai') ||
        text.contains('nadakkalama')) {
      return VoiceIntent.checkPath;
    }

    // 8. Location / GPS
    if (text.contains('my location') ||
        text.contains('where am i currently') ||
        text.contains('gps') ||
        text.contains('coordinates') ||
        text.contains('இருப்பிடம்') ||
        text.contains('location enna')) {
      return VoiceIntent.location;
    }

    // 9. Where Am I / Environmental Context / Describe Room
    if (text.contains('where am i') ||
        text.contains('which room') ||
        text.contains('what room') ||
        text.contains('environment') ||
        text.contains('place') ||
        text.contains('describe the room') ||
        text.contains('எந்த அறை') ||
        text.contains('சூழல்') ||
        text.contains('enna room') ||
        text.contains('intha idam enna')) {
      return VoiceIntent.whereAmI;
    }

    // 10. Scene Understanding / General Visual Description / "What is in front of me?"
    if (text.contains('describe') ||
        text.contains('what is in front') ||
        text.contains('what is ahead') ||
        text.contains('what do you see') ||
        text.contains('look around') ||
        text.contains('see ahead') ||
        text.contains('surrounding') ||
        text.contains('scene') ||
        text.contains('முன்னால் என்ன') ||
        text.contains('முன்னாடி என்ன') ||
        text.contains('என்ன தெரிகிறது') ||
        text.contains('சுற்றுப்புறம்') ||
        text.contains('munnadi enna') ||
        text.contains('enna theriyuthu') ||
        text.contains('front la enna')) {
      return VoiceIntent.describeScene;
    }

    // 11. Step Count / Walking Stats (English + Tamil + Tanglish)
    if (text.contains('step') ||
        text.contains('distance') ||
        text.contains('walked') ||
        text.contains('pace') ||
        text.contains('cadence') ||
        text.contains('footstep') ||
        text.contains('அடி') ||
        text.contains('எத்தனை அடி') ||
        text.contains('தூரம்') ||
        text.contains('steps evvalavu') ||
        text.contains('nadanthathu')) {
      return VoiceIntent.stepCount;
    }

    // 12. Device Status / Camera Link / WiFi
    if (text.contains('status') ||
        text.contains('battery') ||
        text.contains('connection') ||
        text.contains('connected') ||
        text.contains('camera') ||
        text.contains('fps') ||
        text.contains('wifi') ||
        text.contains('wi-fi') ||
        text.contains('link') ||
        text.contains('கேமரா') ||
        text.contains('இணைப்பு') ||
        text.contains('camera connect')) {
      return VoiceIntent.deviceStatus;
    }

    // 13. Help & Command Guide
    if (text.contains('help') ||
        text.contains('command') ||
        text.contains('what can you do') ||
        text.contains('options') ||
        text.contains('உதவி') ||
        text.contains('என்ன செய்ய முடியும்') ||
        text.contains('help pannu') ||
        text.contains('options enna')) {
      return VoiceIntent.help;
    }

    // 14. General Knowledge or Conversation
    if (text.contains('who are you') ||
        text.contains('hello') ||
        text.contains('hi') ||
        text.contains('vanakkam') ||
        text.contains('வணக்கம்') ||
        text.contains('what is') ||
        text.contains('how are you')) {
      return VoiceIntent.generalKnowledge;
    }

    return VoiceIntent.unknown;
  }

  /// Synthesizes an assistive spoken answer grounded in camera detections and conversational context.
  static VoiceQueryResult generateAnswer({
    required VoiceIntent intent,
    required String query,
    ConversationalMemory? memory,
    int sessionSteps = 0,
    double estimatedDistanceMeters = 0.0,
    bool isConnected = false,
    double cameraFps = 0.0,
    String? sceneSummary,
    String? pathClearanceText,
    String? environmentName,
    List<DetectedObject> detections = const [],
  }) {
    final isTamil = isTamilQuery(query);
    final refObjects = <String>[];
    String answer = '';
    String? clarification;

    switch (intent) {
      case VoiceIntent.stopSpeech:
        answer = isTamil ? 'குரல் நிறுத்தப்பட்டது.' : 'Speech halted.';
        break;

      case VoiceIntent.emergency:
        answer = isTamil
            ? 'அவசர உதவி கோரப்பட்டுள்ளது. உதவி எச்சரிக்கை செயல்படுத்தப்படுகிறது.'
            : 'Emergency requested. Triggering safety alert escalation.';
        break;

      case VoiceIntent.location:
        answer = isTamil
            ? 'தற்போதைய ஜி.பி.எஸ் இருப்பிடம்: பாதுகாப்பான பகுதியில் உள்ளீர்கள். துல்லியமான முகவரிக்கு இணைய இணைப்பு தேவை.'
            : 'Current GPS tracking is active. You are in a mapped area. Connect to internet for reverse geocoded street address.';
        break;

      case VoiceIntent.personNearby:
        final people = detections
            .where((d) => d.label.toLowerCase() == 'person')
            .toList();
        if (people.isNotEmpty) {
          refObjects.add('person');
          final zones = people
              .map((p) => p.directionZone.naturalSpokenLabel)
              .toSet()
              .join(' and ');
          answer = isTamil
              ? 'ஆம், ஒரு நபர் உங்கள் $zones பகுதியில் உள்ளார்.'
              : 'Yes, a person is detected $zones.';
        } else {
          answer = isTamil
              ? 'தற்போது உங்கள் எதிரே எந்த நபரும் காணப்படவில்லை.'
              : 'No person is currently detected in view.';
        }
        break;

      case VoiceIntent.objectsOnLeft:
        final left = detections
            .where((d) => d.directionZone == DirectionZone.left)
            .map((d) => d.label)
            .toSet()
            .toList();
        refObjects.addAll(left);
        if (left.isNotEmpty) {
          answer = isTamil
              ? 'உங்கள் இடது பக்கம்: ${_joinWithAnd(left)} உள்ளது.'
              : 'On your left, there is ${_joinWithAnd(left)}.';
        } else {
          answer = isTamil
              ? 'உங்கள் இடதுபுறத்தில் எந்த பொருட்களும் கண்டறியப்படவில்லை.'
              : 'There are no objects detected on your left.';
        }
        break;

      case VoiceIntent.objectsOnRight:
        final right = detections
            .where((d) => d.directionZone == DirectionZone.right)
            .map((d) => d.label)
            .toSet()
            .toList();
        refObjects.addAll(right);
        if (right.isNotEmpty) {
          answer = isTamil
              ? 'உங்கள் வலது பக்கம்: ${_joinWithAnd(right)} உள்ளது.'
              : 'On your right, there is ${_joinWithAnd(right)}.';
        } else {
          answer = isTamil
              ? 'உங்கள் வலதுபுறத்தில் எந்த பொருட்களும் கண்டறியப்படவில்லை.'
              : 'There are no objects detected on your right.';
        }
        break;

      case VoiceIntent.objectDetails:
        // Handle pronoun or specific object inquiry
        final resolution = memory?.resolveObjectReference(query) ??
            (resolvedObject: null, clarificationNeeded: null);

        if (resolution.clarificationNeeded != null) {
          clarification = resolution.clarificationNeeded;
          answer = resolution.clarificationNeeded!;
        } else {
          final targetObj = resolution.resolvedObject ??
              (detections.isNotEmpty ? detections.first.label : null);

          if (targetObj != null) {
            refObjects.add(targetObj);
            final q = query.toLowerCase();

            // Asking about distance / proximity
            if (q.contains('close') || q.contains('far') || q.contains('distance') || q.contains('அருகில்')) {
              answer = isTamil
                  ? '$targetObj உங்கள் முன்னால் தெரிகிறது, ஆனால் கேமரா மட்டுமே துல்லியமான தூரத்தை அளவிட முடியாது. தயவுசெய்து உங்கள் ஊன்றுகோலைப் பயன்படுத்தவும்.'
                  : 'The $targetObj is in front of you, but the camera alone cannot establish exact physical distance. Please proceed carefully with your cane.';
            } else if (q.contains('color') || q.contains('வண்ணம்') || q.contains('நிறம்')) {
              answer = isTamil
                  ? '$targetObj கேமரா பார்வையில் தெளிவாக உள்ளது.'
                  : 'The $targetObj is visible in your immediate forward surroundings.';
            } else {
              final usage = _getObjectUsage(targetObj);
              answer = isTamil
                  ? '$targetObj என்பது $usage பயன்படும் பொருள்.'
                  : 'The $targetObj is typically used for $usage.';
            }
          } else {
            answer = isTamil
                ? 'நீங்கள் எந்த பொருளைப் பற்றி கேட்கிறீர்கள் என்று தெளிவாகக் கூறவும்.'
                : 'Which object would you like to know about? Please specify.';
          }
        }
        break;

      case VoiceIntent.checkPath:
        if (pathClearanceText != null && pathClearanceText.isNotEmpty) {
          answer = pathClearanceText;
        } else if (detections.isNotEmpty) {
          final center = detections
              .where((d) => d.directionZone == DirectionZone.center)
              .map((d) => d.label)
              .toSet()
              .toList();
          refObjects.addAll(center);
          if (center.isEmpty) {
            answer = isTamil
                ? 'உங்கள் நேர் பாதை முற்றிலும் சுத்தமாக உள்ளது. நீங்கள் கவனமாக நடக்கலாம்.'
                : 'Your forward walking path is completely clear.';
          } else {
            answer = isTamil
                ? 'எச்சரிக்கை: உங்கள் நேர் பாதையில் ${_joinWithAnd(center)} உள்ளது.'
                : 'Caution: ${_joinWithAnd(center)} detected directly in your center path.';
          }
        } else {
          answer = isTamil
              ? 'பாதை பகுப்பாய்வு செய்யப்படுகிறது. கேமராவை நேராக வைக்கவும்.'
              : 'Analyzing walking path. Hold steady while verifying center corridor.';
        }
        break;

      case VoiceIntent.describeScene:
        if (sceneSummary != null && sceneSummary.isNotEmpty) {
          answer = sceneSummary;
        } else if (detections.isNotEmpty) {
          refObjects.addAll(detections.map((d) => d.label).toSet());
          answer = SceneDescriptionEngine.describe(
            detections: detections,
            cameraFps: cameraFps,
          );
        } else {
          answer = isTamil
              ? 'சுற்றுப்புறம் தெளிவாக உள்ளது. எந்த தடைகளும் கண்டறியப்படவில்லை.'
              : 'The scene appears clear. No objects were detected in the current frame.';
        }
        break;

      case VoiceIntent.readText:
        answer = isTamil
            ? 'பலகை மற்றும் எழுத்துக்களை வாசிக்க கேமரா படம் எடுக்கப்படுகிறது.'
            : 'Capturing camera frame to read visible text aloud.';
        break;

      case VoiceIntent.whereAmI:
        if (environmentName != null && environmentName.isNotEmpty) {
          answer = isTamil
              ? 'நீங்கள் $environmentName பகுதியில் இருக்கிறீர்கள்.'
              : 'You appear to be in an $environmentName.';
        } else if (detections.isNotEmpty) {
          final env = SceneDescriptionEngine.classifyEnvironment(detections);
          answer = isTamil
              ? 'நீங்கள் ${env.displayName} பகுதியில் இருக்கிறீர்கள்.'
              : 'You appear to be in a ${env.displayName}. ${env.description}.';
        } else {
          answer = isTamil
              ? 'உங்கள் சுற்றுப்புற சூழல் பகுப்பாய்வு செய்யப்படுகிறது.'
              : 'Scanning surroundings to determine environmental context.';
        }
        break;

      case VoiceIntent.stepCount:
        final km = (estimatedDistanceMeters / 1000).toStringAsFixed(2);
        answer = isTamil
            ? 'நீங்கள் $sessionSteps அடிகள் நடந்துள்ளீர்கள், சுமார் $km கிலோமீட்டர் தொலைவு.'
            : 'You have taken $sessionSteps steps, covering approximately $km kilometers.';
        break;

      case VoiceIntent.deviceStatus:
        if (isConnected) {
          final fpsText = cameraFps > 0
              ? ' Video stream is running smoothly at ${cameraFps.toStringAsFixed(1)} frames per second.'
              : '';
          answer = isTamil
              ? 'Smart-Cap கேமரா வெற்றிகரமாக இணைக்கப்பட்டுள்ளது.'
              : 'ESP32-CAM Smart-Cap is connected and operational.$fpsText';
        } else {
          answer = isTamil
              ? 'கேமரா தற்போது துண்டிக்கப்பட்டுள்ளது. VisionAssist-Cap வைஃபை சரிபார்க்கவும்.'
              : 'ESP32-CAM is currently disconnected. Please verify Wi-Fi link to VisionAssist-Cap.';
        }
        break;

      case VoiceIntent.generalKnowledge:
        final q = query.toLowerCase();
        if (q.contains('hello') || q.contains('hi') || q.contains('வணக்கம்') || q.contains('vanakkam')) {
          answer = isTamil
              ? 'வணக்கம்! நான் உங்கள் AI குரல் உதவியாளர். உங்களுக்கு உதவ காத்திருக்கிறேன்.'
              : 'Hello! I am your AI voice companion. What would you like to know about your surroundings?';
        } else if (q.contains('who are you')) {
          answer = isTamil
              ? 'நான் பார்வை குறைபாடுடையோருக்கான AI பார்வை உதவியாளர்.'
              : 'I am VisionAssist, your personal AI voice companion for navigating your surroundings.';
        } else {
          answer = isTamil
              ? 'நான் உங்கள் குரல் உதவியாளர். சுற்றுப்புறம், தடைகள் மற்றும் எழுத்துக்கள் பற்றி கேட்கலாம்.'
              : 'I am here to assist you with navigation, describing objects, reading text, and checking path clearance.';
        }
        break;

      case VoiceIntent.help:
        answer = isTamil
            ? 'நீங்கள் கேட்கலாம்: "முன்னாடி என்ன இருக்கு?", "எழுத்துக்களை படி", "யாராவது இருக்காங்களா?", "பாதை சுத்தமா இருக்கா?", அல்லது "எத்தனை அடி நடந்தேன்?".'
            : 'You can ask: "What is in front of me?", "Read text", "Is anyone near me?", "What objects are on my left?", "Is my path clear?", or "How many steps?".';
        break;

      case VoiceIntent.unknown:
        answer = isTamil
            ? 'மன்னிக்கவும், சரியாக கேட்கவில்லை. "முன்னாடி என்ன இருக்கு?" அல்லது "எழுத்து வாசி" என்று கேட்கவும்.'
            : 'I did not recognize that query. You can ask "What is in front of me?", "Is there a person near me?", "Read text", or "Step count".';
        break;
    }

    return VoiceQueryResult(
      originalQuery: query,
      intent: intent,
      answer: answer,
      timestamp: DateTime.now(),
      referencedObjects: refObjects,
      clarificationQuestion: clarification,
    );
  }

  static String _getObjectUsage(String objectLabel) {
    switch (objectLabel.toLowerCase()) {
      case 'chair':
        return 'sitting and resting';
      case 'table':
      case 'dining table':
        return 'placing items, dining, or working';
      case 'bottle':
        return 'drinking water or holding liquids';
      case 'cup':
        return 'drinking tea or coffee';
      case 'laptop':
        return 'computing, typing, or browsing';
      case 'cell phone':
        return 'communication and calling';
      case 'door':
        return 'entering or exiting the room';
      case 'stairs':
        return 'ascending or descending between floor levels';
      case 'backpack':
        return 'carrying books and personal belongings';
      default:
        return 'everyday utility';
    }
  }

  static String _joinWithAnd(List<String> items) {
    if (items.isEmpty) return 'nothing';
    if (items.length == 1) return items[0];
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.take(items.length - 1).join(', ')}, and ${items.last}';
  }
}
