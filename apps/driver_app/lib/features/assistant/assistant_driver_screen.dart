import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/l10n/driver_strings.dart';

// ===== 1. SHEET & LOGIC =====
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

  @override
  void initState() {
    super.initState();
    // Greeting added in build() after lang is available
  }

  void _addGreeting(String lang) {
    if (_messages.isEmpty) {
      _messages.add({'sender': 'assistant', 'text': t('ai_greeting', lang)});
    }
  }

  void _handleCommand(String query) {
    if (query.trim().isEmpty) return;

    final q = query.trim().toLowerCase();
    setState(() {
      _messages.add({'sender': 'user', 'text': query.trim()});
      _queryController.clear();
    });

    final db = ref.read(driverMockDbProvider);
    final trip = db.currentTrip;

    String response = '';
    if (trip == null) {
      response = 'You do not have an active trip right now. New trips assigned by your operator will appear on Home.';
    } else {
      final route = db.routeOfTrip(trip['routeId'] as String? ?? '');
      final stops = (route?['stops'] as List<dynamic>?) ?? [];
      final bookings = db.passengersOfTrip(trip['id'] as String);
      final checkedIn = List<String>.from(trip['checkedIn'] as List);

      if (q.contains('next stop') || q.contains('తదుపరి') || q.contains('अगला')) {
        final stopName = stops.isNotEmpty ? stops[1]['name'] : 'Destination';
        final city = stops.isNotEmpty ? stops[1]['city'] : '';
        response = 'Next stop: $stopName, $city in about 25 minutes. It is a drop point.';
      } else if (q.contains('who') || q.contains('not checked') || q.contains('missing') || q.contains('రాలేదు')) {
        final missing = bookings.where((b) => !checkedIn.contains(b['id'])).toList();
        if (missing.isEmpty) {
          response = 'All ${bookings.length} passengers have checked in!';
        } else {
          final names = missing.map((b) => "${b['customer']} (${b['seatList']})").join(', ');
          response = '${missing.length} booking(s) not checked in yet: $names';
        }
      } else if (q.contains('how many') || q.contains('board') || q.contains('ఎక్కుతారు') || q.contains('चढ़ेंगे')) {
        final nextStopName = stops.isNotEmpty ? stops[1]['name'] : '';
        final boardingAtNext = bookings.where((b) => b['board'] == nextStopName).toList();
        response = 'At $nextStopName, ${boardingAtNext.length} passenger(s) will board.';
      } else if (q.contains('delay') || q.contains('late') || q.contains('ఆలస్యం') || q.contains('देरी')) {
        db.reportDelay(trip['id'] as String, 30, 'Traffic');
        response = 'Reported 30 minutes delay due to Traffic. Passengers and operator have been notified.';
      } else if (q.contains('directions') || q.contains('map') || q.contains('దారి') || q.contains('రాస్తా')) {
        final targetStop = stops.length > 1 ? stops[1]['name'] : (stops.isNotEmpty ? stops[0]['name'] : 'next stop');
        response = 'Opening directions for $targetStop...';
      } else {
        response = 'Trip ${trip['id']}: ${trip['route']} is ${trip['status']}. ${checkedIn.length} of ${bookings.length} passengers checked in.';
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'assistant', 'text': response});
        });
      }
    });
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
                onPressed: () => _handleCommand(_queryController.text),
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
      onPressed: () => _handleCommand(label),
    );
  }
}
