import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.passphraseTitle, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: onToggleMode,
              child: Text(isManual ? l10n.passphraseAutoGenerate : l10n.passphraseEnterManually),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isManual)
          TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l10n.passphraseManualHint,
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
                tooltip: l10n.passphraseRegenerateTooltip,
              ),
            ],
          ),
      ],
    );
  }
}
