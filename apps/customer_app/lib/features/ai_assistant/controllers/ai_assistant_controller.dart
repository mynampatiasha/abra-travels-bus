import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_models.dart';
import '../services/ai_nlp_service.dart';

final aiAssistantMessagesProvider =
    NotifierProvider<AiAssistantNotifier, List<AiChatMessage>>(
      AiAssistantNotifier.new,
    );

class AiAssistantNotifier extends Notifier<List<AiChatMessage>> {
  @override
  List<AiChatMessage> build() {
    return <AiChatMessage>[
      AiChatMessage(
        sender: 'ai',
        text:
            'Hi! Ask me to find a bus, track your bus, check a refund, or cancel seats. I only see your own bookings, and I ask before changing anything.',
        timestamp: DateTime.now(),
        chips: const <String>[
          'Bengaluru to Hyderabad tomorrow night AC sleeper under 1500',
          'Where is my bus?',
          'What is my boarding point?',
          'Refund status',
          'Show offers',
          'Cancel my booking',
          'I feel unsafe',
        ],
      ),
    ];
  }

  void sendMessage(String query) {
    if (query.trim().isEmpty) return;
    final now = DateTime.now();

    final userMessage = AiChatMessage(
      sender: 'user',
      text: query.trim(),
      timestamp: now,
    );

    final aiReply = AiNlpService.processQuery(query);

    state = [...state, userMessage, aiReply];
  }

  void clearHistory() {
    state = build();
  }
}
