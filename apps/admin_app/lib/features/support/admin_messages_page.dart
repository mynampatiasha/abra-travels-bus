import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_theme/shared_theme.dart';

import 'support_mock_store.dart';

class AdminMessagesPage extends ConsumerStatefulWidget {
  const AdminMessagesPage({super.key});

  @override
  ConsumerState<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends ConsumerState<AdminMessagesPage> {
  String _selectedChannel = 'ALL';
  String _searchQuery = '';
  ChatSessionRecord? _activeSession;
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportStoreProvider);
    final sessions = supportState.chatSessions;

    final filtered = sessions.where((s) {
      if (_selectedChannel != 'ALL' && s.channel != _selectedChannel) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = s.customer.toLowerCase().contains(q) ||
            s.phone.contains(q) ||
            s.lastMessage.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    _activeSession ??= filtered.isNotEmpty ? filtered.first : null;
    final currentSession = _activeSession != null
        ? sessions.firstWhere(
            (s) => s.id == _activeSession!.id,
            orElse: () => _activeSession!,
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat & WhatsApp messages',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer WhatsApp chatbot chats and live support transcripts.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Exporting chat history to CSV...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export history'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showBroadcastModal(context),
                      icon: const Icon(Icons.campaign, size: 16),
                      label: const Text('Broadcast reply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AbraColors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Two-column layout
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      // Sessions List Sidebar
                      SizedBox(
                        width: 360,
                        child: Column(
                          children: [
                            // Search and Channel toggle
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  TextField(
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v),
                                    decoration: InputDecoration(
                                      hintText: 'Search chats or phone...',
                                      prefixIcon:
                                          const Icon(Icons.search, size: 18),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _buildChannelTab('ALL', 'All'),
                                      const SizedBox(width: 8),
                                      _buildChannelTab('WhatsApp', 'WhatsApp'),
                                      const SizedBox(width: 8),
                                      _buildChannelTab('Live Chat', 'Live Chat'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),

                            // List
                            Expanded(
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final s = filtered[index];
                                  final isSelected =
                                      currentSession?.id == s.id;

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor:
                                        AbraColors.skyBlue.withValues(alpha: 0.15),
                                    onTap: () {
                                      setState(() => _activeSession = s);
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: s.channel == 'WhatsApp'
                                          ? Colors.green.shade100
                                          : Colors.blue.shade100,
                                      child: Icon(
                                        s.channel == 'WhatsApp'
                                            ? Icons.chat_bubble
                                            : Icons.headset_mic,
                                        size: 18,
                                        color: s.channel == 'WhatsApp'
                                            ? Colors.green.shade800
                                            : AbraColors.blue,
                                      ),
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          s.customer,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('hh:mm a')
                                              .format(s.lastAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 3),
                                        Text(
                                          s.lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _buildChannelBadge(s.channel),
                                            const Spacer(),
                                            if (s.unreadCount > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade600,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${s.unreadCount}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
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
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),

                      // Chat Conversation Active View
                      Expanded(
                        child: currentSession == null
                            ? const Center(
                                child: Text('Select a chat to view messages'),
                              )
                            : Column(
                                children: [
                                  // Chat Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentSession.customer,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AbraColors.navy,
                                              ),
                                            ),
                                            Text(
                                              '${currentSession.phone} • ${currentSession.channel}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: currentSession.status ==
                                                    'ACTIVE'
                                                ? Colors.green.shade50
                                                : Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            currentSession.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: currentSession.status ==
                                                      'ACTIVE'
                                                  ? Colors.green.shade800
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Message Stream
                                  Expanded(
                                    child: Container(
                                      color: const Color(0xFFF7F8FA),
                                      padding: const EdgeInsets.all(20),
                                      child: ListView.separated(
                                        itemCount:
                                            currentSession.messages.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, idx) {
                                          final m =
                                              currentSession.messages[idx];
                                          final isAgent = m.sender == 'agent';

                                          return Align(
                                            alignment: isAgent
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                maxWidth: 480,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isAgent
                                                    ? const Color(0xFFE7FFDB)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.04),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    m.text,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      DateFormat('hh:mm a')
                                                          .format(m.at),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors.grey.shade500,
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
                                  ),

                                  // Chat Input Composer
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    color: Colors.white,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _replyController,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Reply to customer on ${currentSession.channel}...',
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final text =
                                                _replyController.text.trim();
                                            if (text.isEmpty) return;
                                            ref
                                                .read(supportStoreProvider
                                                    .notifier)
                                                .addChatReply(
                                                  currentSession.id,
                                                  text,
                                                );
                                            _replyController.clear();
                                          },
                                          icon:
                                              const Icon(Icons.send, size: 14),
                                          label: const Text('Send'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                currentSession.channel ==
                                                        'WhatsApp'
                                                    ? const Color(0xFF25D366)
                                                    : AbraColors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelTab(String channel, String label) {
    final isSelected = _selectedChannel == channel;
    return InkWell(
      onTap: () => setState(() => _selectedChannel = channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AbraColors.navy : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelBadge(String channel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: channel == 'WhatsApp'
            ? Colors.green.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        channel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: channel == 'WhatsApp'
              ? Colors.green.shade800
              : AbraColors.blue,
        ),
      ),
    );
  }

  void _showBroadcastModal(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Broadcast WhatsApp Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send notification to all passengers with departures in next 4 hours.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter broadcast update...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Broadcast queued to 184 passengers'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AbraColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Broadcast'),
          ),
        ],
      ),
    );
  }
}
