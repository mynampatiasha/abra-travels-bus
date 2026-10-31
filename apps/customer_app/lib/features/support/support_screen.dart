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
import 'create_ticket_sheet.dart';
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
            error: (Object e, StackTrace _) => const AbraCard(
              child: Text('Could not load the help centre. Check your connection and open this page again.'),
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
                            'No help articles yet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: AbraSpacing.xs),
                          Text(
                            'Our team has not published any help articles yet. You can still contact support below.',
                            textAlign: TextAlign.center,
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
                    ..._contactRows(contact),
                    const SizedBox(height: AbraSpacing.lg),
                    FilledButton.icon(
                      icon: const Icon(Icons.support_agent, size: 16),
                      label: const Text('Create a ticket'),
                      onPressed: () {
                        if (auth is AuthSignedIn) {
                          CreateTicketSheet.show(context);
                        } else {
                          requireSignIn(
                            context,
                            const SignInIntent(returnLocation: AppRoutes.support),
                          );
                        }
                      },
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
              error: (Object e, StackTrace _) => const Text('Could not load your tickets. Check your connection and open this page again.'),
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
                            'You have not raised any tickets.',
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
                              t.number.isEmpty ? 'Ticket' : t.number,
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

  /// Phone, email and hours that staff have saved; a line that is empty is left out.
  List<Widget> _contactRows(ContactInfo contact) {
    final rows = <(IconData, String, String)>[
      (Icons.phone_outlined, 'Phone', contact.phone),
      (Icons.email_outlined, 'Email', contact.email),
      (Icons.access_time, 'Hours', contact.hours),
    ].where((row) => row.$3.trim().isNotEmpty).toList();
    if (rows.isEmpty) {
      return const <Widget>[
        Text(
          'Contact details have not been set up yet. Raise a ticket and we will get back to you.',
          style: TextStyle(color: AbraColors.textSecondary),
        ),
      ];
    }
    return <Widget>[
      for (var i = 0; i < rows.length; i++) ...<Widget>[
        if (i > 0) const Divider(height: AbraSpacing.lg),
        _infoRow(rows[i].$1, rows[i].$2, rows[i].$3),
      ],
    ];
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
