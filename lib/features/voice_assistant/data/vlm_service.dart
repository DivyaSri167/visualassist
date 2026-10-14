import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../object_detection/domain/detected_object.dart';
import '../../object_detection/domain/direction_zone.dart';
import '../../scene_understanding/data/scene_description_engine.dart';
import 'conversational_memory.dart';

const String _prefKeyGeminiApiKey = 'voice_assistant_gemini_api_key';

/// Vision-Language Model service supporting both Cloud VLM (Google Gemini 1.5/2.0 Flash)
/// and 100% Offline On-Device Semantic Grounding for visually impaired users.
class VlmService {
  final http.Client _client;
  String? _cachedApiKey;

  VlmService({http.Client? client}) : _client = client ?? http.Client();

  /// Loads stored API key from SharedPreferences if configured.
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedApiKey = prefs.getString(_prefKeyGeminiApiKey);
      return _cachedApiKey;
    } catch (_) {
      return null;
    }
  }

  /// Sets or updates the Gemini API key.
  Future<void> setApiKey(String? key) async {
    _cachedApiKey = key?.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cachedApiKey == null || _cachedApiKey!.isEmpty) {
        await prefs.remove(_prefKeyGeminiApiKey);
      } else {
        await prefs.setString(_prefKeyGeminiApiKey, _cachedApiKey!);
      }
    } catch (_) {}
  }

  /// Analyzes the camera image and answers the user's question.
  /// If [imageBytes] is null or empty, or if offline/unconfigured, falls back gracefully.
  Future<String> answerVisualQuestion({
    required String query,
    required Uint8List? imageBytes,
    required List<DetectedObject> currentDetections,
    required ConversationalMemory memory,
    String preferredLanguage = 'en',
  }) async {
    final apiKey = await getApiKey();

    final isTamil = preferredLanguage == 'ta' ||
        query.contains(RegExp(r'[\u0B80-\u0BFF]')) ||
        query.toLowerCase().contains('enna') ||
        query.toLowerCase().contains('irukku');

    // 1. Try Cloud VLM if API key is provided and image is present
    if (apiKey != null && apiKey.isNotEmpty && imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final cloudResponse = await _queryGeminiVlm(
          apiKey: apiKey,
          query: query,
          imageBytes: imageBytes,
          memory: memory,
          isTamil: isTamil,
        );
        if (cloudResponse != null && cloudResponse.trim().isNotEmpty) {
          return cloudResponse.trim();
        }
      } catch (_) {
        // Fall back to on-device reasoning if cloud request fails (e.g. offline AP network)
      }
    }

    // 2. On-Device Fallback Grounding
    return _groundOnDevice(
      query: query,
      currentDetections: currentDetections,
      memory: memory,
      isTamil: isTamil,
      hasImage: imageBytes != null && imageBytes.isNotEmpty,
    );
  }

  /// Queries Google Gemini 1.5 Flash VLM API.
  Future<String?> _queryGeminiVlm({
    required String apiKey,
    required String query,
    required Uint8List imageBytes,
    required ConversationalMemory memory,
    required bool isTamil,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final base64Image = base64Encode(imageBytes);
    final contextHistory = memory.buildContextSummary();

    final systemPrompt = isTamil
        ? 'நீங்கள் கண்பார்வையற்ற பயனருக்கான AI குரல் உதவியாளர். திரையை பயனர் பார்க்க முடியாது. சுருக்கமாக 1-2 வாக்கியங்களில் தமிழில் பதிலளிக்கவும். இடது, வலது, முன்னால் போன்ற திசைகளை குறிப்பிடவும். சரியான தூரம் தெரியாவிட்டால் கற்பனை செய்யாதீர்கள்.'
        : 'You are an AI voice companion for a blind user who cannot see the screen. Answer concisely in 1-2 spoken sentences. Describe relative directions (in front, on your left, on your right). Never fabricate visual details or invent exact physical distances. Be honest if unclear.';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {
              'text': '$systemPrompt\n\nRecent conversation:\n$contextHistory\n\nUser Question: $query'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 150,
      }
    });

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final text = candidates[0]['content']['parts'][0]['text'] as String?;
        return text;
      }
    }
    return null;
  }

  /// On-device local semantic grounding when offline or without API key.
  String _groundOnDevice({
    required String query,
    required List<DetectedObject> currentDetections,
    required ConversationalMemory memory,
    required bool isTamil,
    required bool hasImage,
  }) {
    if (!hasImage && currentDetections.isEmpty) {
      return isTamil
          ? 'கேமரா படம் தற்போது கிடைக்கவில்லை. தயவுசெய்து கேமரா இணைப்பை சரிபார்க்கவும்.'
          : 'Camera image is currently unavailable. Please verify the camera connection.';
    }

    final q = query.toLowerCase();

    // Check if user is asking about a specific object
    for (final det in currentDetections) {
      if (q.contains(det.label.toLowerCase())) {
        final zone = det.directionZone.naturalSpokenLabel;
        if (isTamil) {
          return '${det.label} உங்கள் $zone பகுதியில் கண்டறியப்பட்டுள்ளது.';
        }
        return 'Yes, a ${det.label} is detected $zone.';
      }
    }

    // Check if asking what it is used for
    if (q.contains('used for') || q.contains('what is this') || q.contains('how to use')) {
      final recent = memory.getRecentReferencedObjects();
      if (recent.isNotEmpty) {
        final obj = recent.first;
        final usage = _getObjectUsage(obj);
        return isTamil
            ? '$obj: $usage'
            : 'The $obj is typically used for $usage.';
      }
    }

    // Default to scene description engine
    if (currentDetections.isNotEmpty) {
      if (isTamil) {
        final labels = currentDetections.map((d) => d.label).toSet().join(', ');
        return 'உங்கள் எதிரே $labels காணப்படுகின்றன.';
      }
      return SceneDescriptionEngine.describe(detections: currentDetections);
    }

    return isTamil
        ? 'தற்போதைய கேமரா பார்வையில் எந்த தடைகளும் கண்டறியப்படவில்லை.'
        : 'No specific objects were identified in the current camera view.';
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
        return 'everyday utility in this space';
    }
  }

  void dispose() {
    _client.close();
  }
}
