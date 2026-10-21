import 'package:flutter/material.dart';
import 'ai_assistant_sheet.dart';

class FloatingAiButton extends StatelessWidget {
  const FloatingAiButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF12304A), Color(0xFF1677C8), Color(0xFF36BDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1677C8).withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Semantics(
          button: true,
          label: 'Abra AI Assistant',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => AiAssistantSheet.show(context),
            child: const Center(
              child: Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
