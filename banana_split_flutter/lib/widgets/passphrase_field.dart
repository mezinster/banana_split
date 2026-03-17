import 'package:flutter/material.dart';

class PassphraseField extends StatelessWidget {
  final String passphrase;
  final bool isManual;
  final ValueChanged<String> onChanged;
  final VoidCallback onRegenerate;
  final VoidCallback onToggleMode;

  const PassphraseField({
    super.key,
    required this.passphrase,
    required this.isManual,
    required this.onChanged,
    required this.onRegenerate,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Passphrase', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: onToggleMode,
              child: Text(isManual ? 'Auto-generate' : 'Enter manually'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isManual)
          TextField(
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter your passphrase (min 8 characters)',
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    passphrase,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh),
                tooltip: 'Generate new passphrase',
              ),
            ],
          ),
      ],
    );
  }
}
