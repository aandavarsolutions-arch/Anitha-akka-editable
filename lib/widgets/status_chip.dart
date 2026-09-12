import 'package:flutter/material.dart';
import '../../theme.dart';

enum StatusType { paid, partial, pending, active, inactive }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusChip({super.key, required this.label, required this.type});

  Color get _color {
    switch (type) {
      case StatusType.paid:
      case StatusType.active:
        return JarvisTheme.statusPaid;
      case StatusType.partial:
        return JarvisTheme.statusPartial;
      case StatusType.pending:
      case StatusType.inactive:
        return JarvisTheme.statusPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        border: Border.all(color: _color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
