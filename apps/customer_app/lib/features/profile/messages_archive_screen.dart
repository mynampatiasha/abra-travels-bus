import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/gradient_header.dart';

class CustomerMessage {
  const CustomerMessage({
    required this.id,
    required this.at,
    required this.channel,
    required this.kind,
    required this.subject,
    required this.body,
    required this.address,
    this.bookingId,
  });

  factory CustomerMessage.fromJson(Map<String, Object?> json) => CustomerMessage(
        id: json['id'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        channel: json['channel'] as String? ?? 'WHATSAPP',
        kind: json['kind'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        body: json['body'] as String? ?? '',
        address: json['address'] as String? ?? '',
        bookingId: json['bookingId'] as String?,
      );

  final String id;
  final DateTime at;
  final String channel;
  final String kind;
  final String subject;
  final String body;
  final String address;
  final String? bookingId;
}

final customerMessagesProvider =
    FutureProvider.autoDispose<List<CustomerMessage>>((ref) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get(
    'customer/messages',
    query: const <String, Object?>{'pageSize': 50},
  );
  final payload = response.data;
  final rawList = payload is Map && payload['items'] is List
      ? payload['items'] as List
      : payload is List
          ? payload
          : const <Object?>[];
  return rawList
      .whereType<Map<Object?, Object?>>()
      .map((item) => CustomerMessage.fromJson(Map<String, Object?>.from(item)))
      .toList(growable: false);
});

class MessagesArchiveScreen extends ConsumerWidget {
  const MessagesArchiveScreen({super.key});

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return 'm ago';
    if (difference.inHours < 24) return 'h ago';
    if (difference.inDays < 7) return 'd ago';
    return '//';
  }

  static void _showDetails(
    BuildContext context,
    WidgetRef ref,
    CustomerMessage message,
  ) {
    final client = ref.read(appDependenciesProvider).apiClient;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<CustomerMessage>(
          future: () async {
            try {
              final res = await client.get('customer/messages/${message.id}');
              if (res.data is Map) {
                return CustomerMessage.fromJson(Map<String, Object?>.from(res.data as Map));
              }
              return message;
            } catch (_) {
              return message;
            }
          }(),
          initialData: message,
          builder: (context, snapshot) {
            final data = snapshot.data ?? message;
            return AlertDialog(
              title: Row(
                children: [
                  _ChannelBadge(channel: data.channel),
                  const SizedBox(width: AbraSpacing.sm),
                  Expanded(
                    child: Text(
                      data.subject.isNotEmpty ? data.subject : 'Message Details',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.address.isNotEmpty) ...[
                      const Text(
                        'Sent to: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AbraColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                    ],
                    const Text(
                      'Received: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AbraColors.textSecondary,
                      ),
                    ),
                    if (data.bookingId != null) ...[
                      const SizedBox(height: AbraSpacing.xs),
                      const Text(
                        'Booking: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AbraColors.textSecondary,
                        ),
                      ),
                    ],
                    const Divider(height: AbraSpacing.lg),
                    Text(
                      data.body,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerMessagesProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Messages sent to me',
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(customerMessagesProvider.future),
        child: AbraPageContainer(
          maxWidth: AbraSizes.maxFormWidth * 1.3,
          child: state.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AbraSpacing.xxl),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AbraColors.danger,
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Text(
                      'Unable to load messages',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AbraSpacing.sm),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AbraColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(customerMessagesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 60),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AbraSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mark_email_read_outlined,
                              size: 56,
                              color: AbraColors.textSecondary,
                            ),
                            SizedBox(height: AbraSpacing.md),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AbraColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: AbraSpacing.xs),
                            Text(
                              'Copies of tickets and notifications sent to your WhatsApp or email will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AbraColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AbraSpacing.md,
                  vertical: AbraSpacing.lg,
                ),
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: AbraSpacing.sm),
                itemBuilder: (context, index) {
                  final m = messages[index];
                  return AbraCard(
                    child: InkWell(
                      borderRadius: AbraRadius.medium,
                      onTap: () => _showDetails(context, ref, m),
                      child: Padding(
                        padding: const EdgeInsets.all(AbraSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _ChannelBadge(channel: m.channel),
                                const Spacer(),
                                Text(
                                  _formatTime(m.at),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AbraColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AbraSpacing.sm),
                            if (m.subject.isNotEmpty) ...[
                              Text(
                                m.subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AbraColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AbraSpacing.xs),
                            ],
                            Text(
                              m.body,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AbraColors.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChannelBadge extends StatelessWidget {
  const _ChannelBadge({required this.channel});

  final String channel;

  @override
  Widget build(BuildContext context) {
    final upper = channel.toUpperCase();
    final (Color bg, Color fg, String label) = switch (upper) {
      'WHATSAPP' => (const Color(0xFFDCFCE7), const Color(0xFF15803D), 'WhatsApp'),
      'SMS' => (AbraColors.lightBlue, AbraColors.blueDark, 'SMS'),
      'EMAIL' => (const Color(0xFFFEF3C7), const Color(0xFFB45309), 'Email'),
      _ => (AbraColors.lightGray, AbraColors.textSecondary, channel),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AbraRadius.small,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
