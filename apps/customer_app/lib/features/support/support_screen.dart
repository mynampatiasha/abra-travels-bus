import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/guest_prompt_card.dart';
import '../../core/ui/section_header.dart';
import '../../routing/app_routes.dart';
import '../authentication/gate/require_sign_in.dart';
import '../authentication/gate/sign_in_intent.dart';
import 'controllers/support_controller.dart';
import 'models/support_models.dart';
import 'ticket_details_screen.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final faqsAsync = ref.watch(faqsProvider);
    final contactAsync = ref.watch(contactInfoProvider);
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AbraSpacing.md,
          vertical: AbraSpacing.lg,
        ),
        children: <Widget>[
          // Help Centre FAQ section
          const SectionHeader(title: 'Help centre'),
          faqsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AbraSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, StackTrace _) => AbraCard(
              child: Text('Could not load FAQs: $e'),
            ),
            data: (List<FaqItem> faqs) {
              if (faqs.isEmpty) {
                return const AbraCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AbraSpacing.lg),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Coming soon',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: AbraSpacing.xs),
                          Text(
                            'Not connected yet - built in Phase 4',
                            style: TextStyle(
                              color: AbraColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final categories = <String, List<FaqItem>>{};
              for (final f in faqs) {
                categories.putIfAbsent(f.category, () => <FaqItem>[]).add(f);
              }

              return AbraCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: categories.entries.map((cat) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        leading: const Icon(Icons.help_outline, color: AbraColors.blue),
                        title: Text(
                          cat.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AbraColors.deepBlue,
                          ),
                        ),
                        children: cat.value.map((item) {
                          return Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AbraColors.divider),
                              ),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                item.question,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AbraSpacing.lg,
                                    0,
                                    AbraSpacing.lg,
                                    AbraSpacing.md,
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      item.answer,
                                      style: const TextStyle(
                                        color: AbraColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: AbraSpacing.xl),

          // Contact Support Card
          const SectionHeader(title: 'Contact support'),
          contactAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (Object e, StackTrace _) => const SizedBox.shrink(),
            data: (ContactInfo contact) {
              return AbraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _infoRow(Icons.phone_outlined, 'Phone', contact.phone),
                    const Divider(height: AbraSpacing.lg),
                    _infoRow(Icons.chat_outlined, 'WhatsApp', contact.whatsapp),
                    const Divider(height: AbraSpacing.lg),
                    _infoRow(Icons.email_outlined, 'Email', contact.email),
                    const Divider(height: AbraSpacing.lg),
                    _infoRow(Icons.access_time, 'Hours', contact.hours),
                    const SizedBox(height: AbraSpacing.lg),
                    const Wrap(
                      spacing: AbraSpacing.md,
                      runSpacing: AbraSpacing.sm,
                      children: <Widget>[
                        Tooltip(
                          message: 'Not connected yet',
                          child: OutlinedButton(
                            onPressed: null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone, size: 16),
                                SizedBox(width: 8),
                                Text('Call'),
                              ],
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Not connected yet',
                          child: FilledButton(
                            onPressed: null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.support_agent, size: 16),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Create a ticket',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AbraSpacing.xl),

          // My Tickets section
          if (auth is AuthSignedIn) ...<Widget>[
            const SectionHeader(title: 'My tickets'),
            ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => Text('Could not load tickets: $e'),
              data: (List<SupportTicket> tickets) {
                if (tickets.isEmpty) {
                  return const AbraCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AbraSpacing.lg),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.inbox_outlined,
                            size: 40,
                            color: AbraColors.textDisabled,
                          ),
                          SizedBox(height: AbraSpacing.sm),
                          Text(
                            'Not connected yet - built in Phase 4',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AbraColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: tickets.map((t) {
                    final color = _statusColor(t.status);
                    return Container(
                      margin: const EdgeInsets.only(bottom: AbraSpacing.sm),
                      child: AbraCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TicketDetailsScreen(ticketId: t.id),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    t.subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AbraSpacing.sm,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AbraRadius.pill),
                                    border: Border.all(color: color),
                                  ),
                                  child: Text(
                                    t.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AbraSpacing.xs),
                            Text(
                              '${t.id} • ${t.messages.length} message${t.messages.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AbraColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ] else ...<Widget>[
            GuestPromptCard(
              compact: true,
              icon: Icons.confirmation_number_outlined,
              title: 'Have a problem with a booking?',
              message: 'Sign in to raise tickets and track resolution with our customer support team.',
              actionLabel: 'Sign in',
              onAction: () => requireSignIn(
                context,
                const SignInIntent(returnLocation: AppRoutes.support),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: AbraColors.blueDark),
        const SizedBox(width: AbraSpacing.md),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AbraColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: AbraSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AbraColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
