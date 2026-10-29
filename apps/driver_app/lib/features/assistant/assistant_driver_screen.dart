import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import '../../app/providers.dart';
import '../../core/l10n/driver_strings.dart';

class AssistantDriverSheet extends ConsumerStatefulWidget {
  const AssistantDriverSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AssistantDriverSheet(),
    );
  }

  @override
  ConsumerState<AssistantDriverSheet> createState() => _AssistantDriverSheetState();
}

class _AssistantDriverSheetState extends ConsumerState<AssistantDriverSheet> {
  final TextEditingController _queryController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isListening = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _addGreeting(String lang) {
    if (_messages.isEmpty) {
      _messages.add({'sender': 'assistant', 'text': t('ai_greeting', lang)});
    }
  }

  Future<void> _handleCommand(String query) async {
    final text = query.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _queryController.clear();
      _isLoading = true;
    });

    final client = ref.read(driverApiClientProvider);
    final lang = ref.read(driverLanguageProvider);

    final payloadMessages = <Map<String, String>>[];
    for (final m in _messages) {
      final content = m['text']?.trim() ?? '';
      if (content.isNotEmpty) {
        payloadMessages.add({
          'role': m['sender'] == 'user' ? 'user' : 'assistant',
          'content': content,
        });
      }
    }

    try {
      final res = await client.post(
        'assistant/chat',
        body: <String, Object?>{
          'messages': payloadMessages,
          'language': lang,
        },
      );

      final data = res.data is Map ? res.data as Map : <String, Object?>{};
      final reply = data['reply'] as String? ?? 'No response';

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add({'sender': 'assistant', 'text': reply});
      });
    } on AppException catch (e) {
      if (!mounted) return;
      final msg = e.failure is ApiFailure
          ? (e.failure as ApiFailure).message
          : 'The assistant could not answer. Please try again.';
      setState(() {
        _isLoading = false;
        _messages.add({'sender': 'assistant', 'text': msg});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add({
          'sender': 'assistant',
          'text': 'The assistant could not answer. Please try again.',
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(driverLanguageProvider);
    _addGreeting(lang);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.mic, color: Color(0xFF0284C7)),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Driver Assistant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Multilingual quick suggestion chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _suggestionChip(t('ai_next_stop', lang)),
                const SizedBox(width: 8),
                _suggestionChip(t('ai_who_missing', lang)),
                const SizedBox(width: 8),
                _suggestionChip(t('ai_how_many_board', lang)),
                const SizedBox(width: 8),
                _suggestionChip(t('ai_report_delay', lang)),
                const SizedBox(width: 8),
                _suggestionChip(t('ai_trip_summary', lang)),
              ],
            ),
          ),
          const Divider(height: 24),
          // Chat log
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1677C8) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser ? Colors.white : const Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Input row
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? const Color(0xFFEF4444) : const Color(0xFF1677C8),
                  size: 28,
                ),
                onPressed: () {
                  setState(() => _isListening = !_isListening);
                  if (_isListening) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Listening... speak now'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              Expanded(
                child: TextField(
                  controller: _queryController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Ask or tap a command...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  onSubmitted: _handleCommand,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF1677C8)),
                onPressed: _isLoading ? null : () => _handleCommand(_queryController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(
      backgroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
      ),
      onPressed: _isLoading ? null : () => _handleCommand(label),
    );
  }
}
