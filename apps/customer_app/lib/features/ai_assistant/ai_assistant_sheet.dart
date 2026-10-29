import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'controllers/ai_assistant_controller.dart';

class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiAssistantSheet(),
    );
  }

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    _inputController.clear();
    ref.read(aiAssistantMessagesProvider.notifier).sendMessage(query);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiAssistantMessagesProvider);
    final statusAsync = ref.watch(aiAssistantStatusProvider);
    final isAvailable = statusAsync.value ?? true;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AbraColors.lightGray,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AbraSpacing.md,
              vertical: AbraSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AbraColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AbraColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AbraColors.lightBlue,
                    borderRadius: AbraRadius.small,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AbraColors.blue, size: 20),
                ),
                const SizedBox(width: AbraSpacing.sm),
                const Text(
                  'Abra AI Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AbraColors.deepBlue,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Server unavailable banner if applicable
          if (!isAvailable)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.md, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Assistant is currently unavailable on this server.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ),

          // Message history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AbraSpacing.md),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isUser = m.sender == 'user';

                return Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(AbraSpacing.md),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AbraColors.blue
                            : m.isDanger
                                ? AbraColors.dangerContainer
                                : AbraColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isUser
                            ? null
                            : Border.all(
                                color: m.isDanger
                                    ? AbraColors.danger.withValues(alpha: 0.4)
                                    : AbraColors.border,
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: isUser
                                  ? Colors.white
                                  : m.isDanger
                                      ? AbraColors.danger
                                      : AbraColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                          if (!isUser && m.turnId != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => ref
                                      .read(aiAssistantMessagesProvider.notifier)
                                      .sendFeedback(m.turnId!, 'UP'),
                                  child: Icon(
                                    m.feedback == 'UP'
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_alt_outlined,
                                    size: 16,
                                    color: m.feedback == 'UP'
                                        ? AbraColors.blue
                                        : AbraColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => ref
                                      .read(aiAssistantMessagesProvider.notifier)
                                      .sendFeedback(m.turnId!, 'DOWN'),
                                  child: Icon(
                                    m.feedback == 'DOWN'
                                        ? Icons.thumb_down
                                        : Icons.thumb_down_alt_outlined,
                                    size: 16,
                                    color: m.feedback == 'DOWN'
                                        ? AbraColors.danger
                                        : AbraColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Proposed Actions
                    if (m.proposals.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      for (final p in m.proposals)
                        Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(AbraSpacing.sm + 2),
                          decoration: BoxDecoration(
                            color: AbraColors.white,
                            borderRadius: AbraRadius.medium,
                            border: Border.all(color: AbraColors.skyContainer),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.rule_rounded, size: 16, color: AbraColors.blue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.description,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (p.status == 'WAITING') ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: AbraColors.textSecondary,
                                      ),
                                      onPressed: () => ref
                                          .read(aiAssistantMessagesProvider.notifier)
                                          .declineAction(p.id),
                                      child: const Text('Decline', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: AbraColors.blue,
                                      ),
                                      onPressed: () => ref
                                          .read(aiAssistantMessagesProvider.notifier)
                                          .confirmAction(p.id),
                                      child: const Text('Confirm', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      p.status == 'DONE'
                                          ? Icons.check_circle_outline
                                          : p.status == 'DECLINED'
                                              ? Icons.cancel_outlined
                                              : Icons.error_outline,
                                      size: 14,
                                      color: p.status == 'DONE'
                                          ? const Color(0xFF16A34A)
                                          : p.status == 'DECLINED'
                                              ? AbraColors.textSecondary
                                              : AbraColors.danger,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      p.resultMessage ?? p.status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.status == 'DONE'
                                            ? const Color(0xFF16A34A)
                                            : p.status == 'DECLINED'
                                                ? AbraColors.textSecondary
                                                : AbraColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],

                    // Suggestion Chips
                    if (m.chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: m.chips.map((chipText) {
                          return ActionChip(
                            label: Text(
                              chipText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AbraColors.blueDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AbraColors.lightBlue,
                            side: BorderSide.none,
                            onPressed: isAvailable ? () => _send(chipText) : null,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),

          // Prompt input bar
          Container(
            padding: EdgeInsets.fromLTRB(
              AbraSpacing.md,
              AbraSpacing.sm,
              AbraSpacing.md,
              AbraSpacing.sm + bottomInset,
            ),
            decoration: const BoxDecoration(
              color: AbraColors.white,
              border: Border(top: BorderSide(color: AbraColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: isAvailable,
                    decoration: InputDecoration(
                      hintText: isAvailable
                          ? 'Ask Abra Assistant...'
                          : 'Assistant not available...',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AbraSpacing.md,
                        vertical: AbraSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AbraRadius.pill),
                        borderSide: const BorderSide(color: AbraColors.border),
                      ),
                      filled: true,
                      fillColor: AbraColors.lightGray,
                    ),
                    onSubmitted: isAvailable ? (val) => _send(val) : null,
                  ),
                ),
                const SizedBox(width: AbraSpacing.sm),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AbraColors.blue),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: isAvailable ? () => _send(_inputController.text) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
