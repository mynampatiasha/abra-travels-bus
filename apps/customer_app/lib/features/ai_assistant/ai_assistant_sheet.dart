import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../routing/app_routes.dart';
import '../booking/controllers/url_launcher_provider.dart';
import 'controllers/ai_assistant_controller.dart';
import 'models/ai_models.dart';

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

  void _handleAction(AiAction action) {
    switch (action.actionType) {
      case 'call':
        if (action.payload != null) {
          ref.read(urlLauncherProvider)(
            Uri(scheme: 'tel', path: action.payload),
          );
        }
        break;
      case 'copy':
        if (action.payload != null) {
          Clipboard.setData(ClipboardData(text: action.payload!));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied ${action.payload!}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'track':
        Navigator.of(context).pop();
        context.push(AppRoutes.myTrips);
        break;
      case 'route':
        Navigator.of(context).pop();
        context.push(AppRoutes.home);
        break;
      case 'cancel':
        Navigator.of(context).pop();
        context.push(AppRoutes.myTrips);
        break;
      case 'map':
        if (action.payload != null) {
          ref.read(urlLauncherProvider)(
            Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(action.payload!)}',
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiAssistantMessagesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AbraColors.lightGray,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle & title bar
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

          // Message history list
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
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
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
                      child: Text(
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
                    ),

                    // Cards attached to AI message
                    if (m.cards.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      for (final card in m.cards)
                        Container(
                          width: MediaQuery.of(context).size.width * 0.82,
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(AbraSpacing.sm),
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
                                  Expanded(
                                    child: Text(
                                      card.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (card.price != null)
                                    Text(
                                      card.price!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AbraColors.blueDark,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                card.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AbraColors.textSecondary,
                                ),
                              ),
                              if (card.action != null) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(color: AbraColors.blue),
                                      foregroundColor: AbraColors.blue,
                                    ),
                                    onPressed: () => _handleAction(card.action!),
                                    child: Text(card.action!.label, style: const TextStyle(fontSize: 12)),
                                  ),
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
                            onPressed: () => _send(chipText),
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

          // Bottom prompt input field
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
                    decoration: InputDecoration(
                      hintText: 'Ask in English, Telugu, or Hindi...',
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
                    onSubmitted: (val) => _send(val),
                  ),
                ),
                const SizedBox(width: AbraSpacing.sm),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AbraColors.blue),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () => _send(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
