import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/ui/gradient_header.dart';
import 'controllers/support_controller.dart';
import 'models/support_models.dart';

class TicketDetailsScreen extends ConsumerStatefulWidget {
  const TicketDetailsScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  ConsumerState<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends ConsumerState<TicketDetailsScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _replyController.clear();
    try {
      await ref.read(supportTicketsProvider.notifier).reply(
            ticketId: widget.ticketId,
            message: text,
          );
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return AbraColors.blue;
      case 'IN_PROGRESS':
        return AbraColors.orange;
      case 'RESOLVED':
        return AbraColors.teal;
      case 'CLOSED':
        return AbraColors.textDisabled;
      default:
        return AbraColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketDetailProvider(widget.ticketId));

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Ticket ${ticketAsync.value?.number ?? ''}'.trim(),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) =>
            const Center(child: Text('Could not load this ticket. Check your connection and try again.')),
        data: (SupportTicket? ticket) {
          if (ticket == null) {
            return const Center(child: Text('This ticket could not be found.'));
          }

          return Column(
            children: <Widget>[
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AbraSpacing.md),
                decoration: const BoxDecoration(
                  color: AbraColors.white,
                  border: Border(
                    bottom: BorderSide(color: AbraColors.divider),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AbraColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AbraSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(ticket.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AbraRadius.pill),
                            border: Border.all(
                              color: _statusColor(ticket.status),
                            ),
                          ),
                          child: Text(
                            ticket.status.replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(ticket.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    Text(
                      'Category: ${ticket.category} • Priority: ${ticket.priority}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AbraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Message Thread
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  itemCount: ticket.messages.length,
                  itemBuilder: (context, index) {
                    final msg = ticket.messages[index];
                    final isMe = msg.sender == 'customer';

                    return Align(
                      alignment: isMe
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
                        padding: const EdgeInsets.all(AbraSpacing.md),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AbraColors.blue : AbraColors.lightGray,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              isMe ? 'You' : 'Abra Support Agent',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AbraColors.blueDark,
                              ),
                            ),
                            const SizedBox(height: AbraSpacing.xs),
                            Text(
                              msg.text,
                              style: TextStyle(
                                fontSize: 14,
                                color: isMe ? Colors.white : AbraColors.textPrimary,
                              ),
                            ),
                            if (msg.attachments.isNotEmpty) ...<Widget>[
                              const SizedBox(height: AbraSpacing.sm),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.attach_file,
                                    size: 14,
                                    color: isMe ? Colors.white70 : Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.attachments.first,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: isMe ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AbraSpacing.xs),
                            Align(
                              alignment: AlignmentDirectional.bottomEnd,
                              child: Text(
                                '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white60 : Colors.black38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Reply Bar
              Container(
                // The assistant button floats at the bottom right: keep Send clear of it
                padding: const EdgeInsetsDirectional.fromSTEB(AbraSpacing.sm, AbraSpacing.sm, 72, AbraSpacing.sm),
                decoration: const BoxDecoration(
                  color: AbraColors.white,
                  border: Border(top: BorderSide(color: AbraColors.divider)),
                ),
                child: SafeArea(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
                            hintStyle: const TextStyle(fontSize: 14),
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
                          onSubmitted: (_) => _sendReply(),
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.sm),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AbraColors.blue,
                        ),
                        tooltip: 'Send',
                        icon: const Icon(Icons.send, size: 18),
                        onPressed: _sending ? null : _sendReply,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
