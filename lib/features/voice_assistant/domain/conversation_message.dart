import '../data/voice_query_engine.dart';

/// Speaker role in the conversational assistant.
enum MessageSpeaker {
  user,
  assistant,
  system,
}

/// Represents a single conversational turn in the interactive voice assistant.
class ConversationTurn {
  final String id;
  final MessageSpeaker speaker;
  final String text;
  final VoiceIntent intent;
  final DateTime timestamp;
  final List<String> referencedObjects;
  final String? language; // 'en', 'ta', 'tanglish'

  const ConversationTurn({
    required this.id,
    required this.speaker,
    required this.text,
    this.intent = VoiceIntent.unknown,
    required this.timestamp,
    this.referencedObjects = const [],
    this.language,
  });

  ConversationTurn copyWith({
    String? id,
    MessageSpeaker? speaker,
    String? text,
    VoiceIntent? intent,
    DateTime? timestamp,
    List<String>? referencedObjects,
    String? language,
  }) {
    return ConversationTurn(
      id: id ?? this.id,
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      intent: intent ?? this.intent,
      timestamp: timestamp ?? this.timestamp,
      referencedObjects: referencedObjects ?? this.referencedObjects,
      language: language ?? this.language,
    );
  }
}
