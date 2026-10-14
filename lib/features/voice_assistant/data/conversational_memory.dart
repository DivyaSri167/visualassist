import '../domain/conversation_message.dart';
import 'voice_query_engine.dart';

/// Manages short-term conversation context for multi-turn interactions,
/// pronoun resolution, object disambiguation, and context-aware follow-up reasoning.
class ConversationalMemory {
  final int maxHistory;
  final List<ConversationTurn> _turns = [];

  ConversationalMemory({this.maxHistory = 10});

  List<ConversationTurn> get turns => List.unmodifiable(_turns);

  /// Adds a new conversational turn to memory.
  void recordTurn({
    required MessageSpeaker speaker,
    required String text,
    VoiceIntent intent = VoiceIntent.unknown,
    List<String> referencedObjects = const [],
    String? language,
  }) {
    final turn = ConversationTurn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      speaker: speaker,
      text: text,
      intent: intent,
      timestamp: DateTime.now(),
      referencedObjects: referencedObjects,
      language: language,
    );

    _turns.add(turn);
    if (_turns.length > maxHistory) {
      _turns.removeAt(0);
    }
  }

  /// Clears all conversation history for privacy or session reset.
  void clear() {
    _turns.clear();
  }

  /// Finds recently referenced objects across recent turns.
  List<String> getRecentReferencedObjects() {
    final set = <String>{};
    for (final turn in _turns.reversed) {
      for (final obj in turn.referencedObjects) {
        set.add(obj.toLowerCase().trim());
      }
      if (set.length >= 3) break;
    }
    return set.toList();
  }

  /// Checks if query is an anaphoric / pronoun follow-up reference.
  bool containsPronounReference(String query) {
    final q = query.toLowerCase().trim();
    final words = q.split(RegExp(r'\s+'));

    // English pronoun cues
    const enPronouns = {'it', 'this', 'that', 'the object', 'that object', 'the person', 'them'};
    for (final p in enPronouns) {
      if (words.contains(p) || q.contains(p)) return true;
    }

    // Tamil cues
    const taPronouns = {'அது', 'இது', 'அந்த பொருள்', 'இந்த பொருள்', 'அவர்', 'அவங்க'};
    for (final p in taPronouns) {
      if (q.contains(p)) return true;
    }

    // Tanglish cues
    const tanglishPronouns = {'athu', 'ithu', 'antha object', 'intha object', 'avanga', 'ithula', 'athula'};
    for (final p in tanglishPronouns) {
      if (words.contains(p) || q.contains(p)) return true;
    }

    return false;
  }

  /// Resolves the intended object of a follow-up query.
  ///
  /// Returns:
  /// - (resolvedObject: 'chair', clarificationNeeded: null) if unambiguous.
  /// - (resolvedObject: null, clarificationNeeded: 'Are you asking about the chair or the table?') if multiple objects.
  /// - (resolvedObject: null, clarificationNeeded: null) if no recent objects in context.
  ({String? resolvedObject, String? clarificationNeeded}) resolveObjectReference(String query) {
    final recent = getRecentReferencedObjects();
    if (recent.isEmpty) {
      return (resolvedObject: null, clarificationNeeded: null);
    }

    if (recent.length == 1) {
      return (resolvedObject: recent.first, clarificationNeeded: null);
    }

    // Check if the query itself mentions one of the candidate objects
    final q = query.toLowerCase();
    for (final obj in recent) {
      if (q.contains(obj)) {
        return (resolvedObject: obj, clarificationNeeded: null);
      }
    }

    // Ambiguous: multiple recent objects were discussed
    final objList = recent.take(2).join(' or the ');
    final isTamil = query.contains(RegExp(r'[\u0B80-\u0BFF]')) || q.contains('enna') || q.contains('athu');
    final clarification = isTamil
        ? 'நீங்கள் ${recent.take(2).join(" அல்லது ")} பற்றி கேட்கிறீர்களா?'
        : 'Are you asking about the $objList?';

    return (resolvedObject: null, clarificationNeeded: clarification);
  }

  /// Builds context history suitable for VLM or conversational prompt grounding.
  String buildContextSummary() {
    if (_turns.isEmpty) return 'No previous conversational context.';

    final sb = StringBuffer();
    for (final turn in _turns) {
      final role = turn.speaker == MessageSpeaker.user ? 'User' : 'Assistant';
      sb.writeln('$role: ${turn.text}');
    }
    return sb.toString().trim();
  }
}
