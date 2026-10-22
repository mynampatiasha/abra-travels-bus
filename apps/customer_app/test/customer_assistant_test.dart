import 'package:customer_app/features/ai_assistant/controllers/ai_assistant_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('aiAssistantStatusProvider returns availability from backend', (tester) async {
    final app = TestApp(
      stored: storedSession,
      handler: (req) async {
        if (req.path == 'me') return currentUserResponse;
        if (req.path.contains('assistant/status')) {
          return FakeResponse.ok(<String, Object?>{
            'available': true,
            'provider': 'groq',
          });
        }
        return const FakeResponse(404, <String, Object?>{'message': 'Not found'});
      },
    );
    await app.pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final sub = container.listen(aiAssistantStatusProvider, (_, _) {});
    addTearDown(sub.close);
    await app.run(tester, container.read(aiAssistantStatusProvider.future));
    expect(container.read(aiAssistantStatusProvider).value, isTrue);
  });

  testWidgets('AI Assistant controller sends message and accepts reply with proposals', (
    tester,
  ) async {
    final app = TestApp(
      stored: storedSession,
      handler: (req) async {
        if (req.path == 'me') return currentUserResponse;
        if (req.path.contains('assistant/status')) {
          return FakeResponse.ok(<String, Object?>{
            'available': true,
            'provider': 'groq',
          });
        }
        if (req.path.contains('assistant/chat')) {
          return FakeResponse.ok(<String, Object?>{
            'reply': 'I can help you cancel seats 2A, 2B.',
            'turnId': 'turn-999',
            'toolsUsed': ['propose_cancel_booking'],
            'proposals': [
              {
                'id': 'act-1',
                'description': 'Cancel seats 2A, 2B with ₹1,200 refund',
              },
            ],
          });
        }
        if (req.path.contains('assistant/actions/act-1/confirm')) {
          return FakeResponse.ok(<String, Object?>{
            'status': 'DONE',
            'message': 'Booking cancelled successfully.',
          });
        }
        return const FakeResponse(404, <String, Object?>{'message': 'Not found'});
      },
    );
    await app.pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    final sub = container.listen(aiAssistantStatusProvider, (_, _) {});
    addTearDown(sub.close);
    await app.run(tester, container.read(aiAssistantStatusProvider.future));
    expect(container.read(aiAssistantStatusProvider).value, isTrue);

    final notifier = container.read(aiAssistantMessagesProvider.notifier);
    await app.run(tester, notifier.sendMessage('Cancel my booking'));

    final messages = container.read(aiAssistantMessagesProvider);
    expect(messages.length, 3); // initial greeting + user + ai
    expect(messages.last.text, 'I can help you cancel seats 2A, 2B.');
    expect(messages.last.turnId, 'turn-999');
    expect(messages.last.proposals.length, 1);
    expect(messages.last.proposals.first.description, 'Cancel seats 2A, 2B with ₹1,200 refund');

    // Confirm action
    await app.run(tester, notifier.confirmAction('act-1'));
    final afterConfirm = container.read(aiAssistantMessagesProvider);
    expect(afterConfirm.last.proposals.first.status, 'DONE');
    expect(afterConfirm.last.proposals.first.resultMessage, 'Booking cancelled successfully.');
  });
}
