import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Stands in for a window that a later build step adds.
class NotBuiltYet extends StatelessWidget {
  const NotBuiltYet({super.key, required this.icon, required this.window});

  final IconData icon;
  final String window;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.mutedForeground),
            const SizedBox(height: 12),
            Text(window, style: theme.textTheme.h4),
            const SizedBox(height: 4),
            Text('This window is not built yet.', style: theme.textTheme.muted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
