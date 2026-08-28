import 'package:flutter/material.dart';

/// Inline error message. ADR 0005 guardrail: Deep Red (wired as
/// `colorScheme.error`) NEVER carries meaning alone — always icon + text, so
/// red-as-brand (Signal Red chrome) and red-as-error stay distinguishable,
/// and the message still reads for color-blind users and in both themes.
class AppErrorText extends StatelessWidget {
  const AppErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// SnackBar counterpart — same icon+text discipline, used for failures that
/// happen after a screen has already been dismissed.
void showErrorSnack(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: scheme.error,
      content: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onError),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    ),
  );
}

/// Neutral confirmation counterpart, so success and failure never rely on
/// color alone to tell them apart.
void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
