import 'package:flutter/foundation.dart';

@immutable
class AiAction {
  const AiAction({
    required this.label,
    required this.actionType,
    this.payload,
  });

  final String label;
  final String actionType; // 'route', 'trip', 'track', 'call', 'copy', 'cancel'
  final String? payload;
}

@immutable
class AiCardData {
  const AiCardData({
    required this.title,
    required this.subtitle,
    this.badge,
    this.price,
    this.action,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final String? price;
  final AiAction? action;
}

@immutable
class AiChatMessage {
  const AiChatMessage({
    required this.sender, // 'user' or 'ai'
    required this.text,
    required this.timestamp,
    this.cards = const <AiCardData>[],
    this.chips = const <String>[],
    this.isDanger = false,
  });

  final String sender;
  final String text;
  final DateTime timestamp;
  final List<AiCardData> cards;
  final List<String> chips;
  final bool isDanger;
}
