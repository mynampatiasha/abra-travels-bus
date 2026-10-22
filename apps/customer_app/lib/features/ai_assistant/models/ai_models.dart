import 'package:flutter/foundation.dart';

@immutable
class AiActionProposal {
  const AiActionProposal({
    required this.id,
    required this.description,
    this.status = 'WAITING',
    this.resultMessage,
  });

  final String id;
  final String description;
  final String status; // 'WAITING', 'CONFIRMED', 'DECLINED', 'FAILED'
  final String? resultMessage;

  AiActionProposal copyWith({String? status, String? resultMessage}) {
    return AiActionProposal(
      id: id,
      description: description,
      status: status ?? this.status,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
}

@immutable
class AiChatMessage {
  const AiChatMessage({
    required this.sender, // 'user' or 'ai'
    required this.text,
    required this.timestamp,
    this.turnId,
    this.proposals = const <AiActionProposal>[],
    this.chips = const <String>[],
    this.isDanger = false,
    this.feedback, // 'UP' or 'DOWN'
  });

  final String sender;
  final String text;
  final DateTime timestamp;
  final String? turnId;
  final List<AiActionProposal> proposals;
  final List<String> chips;
  final bool isDanger;
  final String? feedback;

  AiChatMessage copyWith({
    String? feedback,
    List<AiActionProposal>? proposals,
  }) {
    return AiChatMessage(
      sender: sender,
      text: text,
      timestamp: timestamp,
      turnId: turnId,
      proposals: proposals ?? this.proposals,
      chips: chips,
      isDanger: isDanger,
      feedback: feedback ?? this.feedback,
    );
  }
}
