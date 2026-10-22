import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import '../../../app/providers.dart';
import '../models/ai_models.dart';

final aiAssistantStatusProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    final client = ref.watch(appDependenciesProvider).apiClient;
    final res = await client.get('assistant/status');
    if (res.data is Map) {
      return (res.data as Map)['available'] == true;
    }
    return false;
  } catch (_) {
    return false;
  }
});

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
          'Where is my bus?',
          'What is my boarding point?',
          'Refund status',
          'Show offers',
          'Cancel my booking',
        ],
      ),
    ];
  }

  Future<void> sendMessage(String query, {String language = 'en'}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final userMessage = AiChatMessage(
      sender: 'user',
      text: trimmed,
      timestamp: DateTime.now(),
    );

    final currentMessages = [...state, userMessage];
    state = currentMessages;

    final client = ref.read(appDependenciesProvider).apiClient;

    // Build payload for backend: list of { role: 'user' | 'assistant', content: string }
    final payloadMessages = <Map<String, String>>[];
    for (final m in currentMessages) {
      if (m.text.isNotEmpty) {
        payloadMessages.add({
          'role': m.sender == 'user' ? 'user' : 'assistant',
          'content': m.text,
        });
      }
    }

    try {
      final res = await client.post(
        'assistant/chat',
        body: <String, Object?>{
          'messages': payloadMessages,
          'language': language,
        },
      );

      final data = res.data is Map ? Map<String, Object?>.from(res.data as Map) : <String, Object?>{};
      final replyText = data['reply'] as String? ?? 'No response received.';
      final turnId = data['turnId'] as String?;
      final rawProposals = data['proposals'] is List ? data['proposals'] as List : const <Object?>[];

      final proposals = rawProposals
          .whereType<Map<Object?, Object?>>()
          .map((p) => AiActionProposal(
                id: p['id'] as String? ?? '',
                description: p['description'] as String? ?? '',
              ))
          .toList();

      final aiMessage = AiChatMessage(
        sender: 'ai',
        text: replyText,
        timestamp: DateTime.now(),
        turnId: turnId,
        proposals: proposals,
      );

      state = [...state, aiMessage];
    } on AppException catch (e) {
      final msg = e.failure is ApiFailure
          ? (e.failure as ApiFailure).message
          : 'Unable to reach the assistant. Please try again.';
      state = [
        ...state,
        AiChatMessage(
          sender: 'ai',
          text: msg,
          timestamp: DateTime.now(),
          isDanger: true,
        ),
      ];
    } catch (e) {
      state = [
        ...state,
        AiChatMessage(
          sender: 'ai',
          text: 'Unable to reach the assistant. Please try again.',
          timestamp: DateTime.now(),
          isDanger: true,
        ),
      ];
    }
  }

  Future<void> confirmAction(String actionId) async {
    final client = ref.read(appDependenciesProvider).apiClient;
    try {
      final res = await client.post('assistant/actions/$actionId/confirm');
      final message = res.data is Map
          ? (res.data as Map)['message'] as String? ?? 'Confirmed'
          : 'Confirmed';

      _updateProposal(actionId, 'DONE', message);
    } on AppException catch (e) {
      final msg = e.failure is ApiFailure
          ? (e.failure as ApiFailure).message
          : 'Action confirmation failed.';
      _updateProposal(actionId, 'FAILED', msg);
    } catch (_) {
      _updateProposal(actionId, 'FAILED', 'Action confirmation failed.');
    }
  }

  Future<void> declineAction(String actionId) async {
    final client = ref.read(appDependenciesProvider).apiClient;
    try {
      await client.post('assistant/actions/$actionId/decline');
      _updateProposal(actionId, 'DECLINED', 'Declined');
    } catch (_) {
      _updateProposal(actionId, 'DECLINED', 'Declined');
    }
  }

  void _updateProposal(String actionId, String status, String message) {
    state = state.map((m) {
      if (m.proposals.any((p) => p.id == actionId)) {
        return m.copyWith(
          proposals: m.proposals
              .map((p) => p.id == actionId
                  ? p.copyWith(status: status, resultMessage: message)
                  : p)
              .toList(),
        );
      }
      return m;
    }).toList();
  }

  Future<void> sendFeedback(String turnId, String value) async {
    final client = ref.read(appDependenciesProvider).apiClient;
    try {
      await client.post(
        'assistant/messages/$turnId/feedback',
        body: <String, Object?>{'value': value},
      );
      state = state.map((m) {
        if (m.turnId == turnId) {
          return m.copyWith(feedback: value);
        }
        return m;
      }).toList();
    } catch (_) {}
  }

  void clearHistory() {
    state = build();
  }
}
