import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:banana_split_flutter/services/export_service.dart';
import 'package:banana_split_flutter/state/create_notifier.dart';
import 'package:banana_split_flutter/widgets/passphrase_field.dart';
import 'package:banana_split_flutter/widgets/qr_grid.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CreateNotifier>(
      builder: (context, notifier, _) {
        final l10n = AppLocalizations.of(context)!;
        if (notifier.isGenerating) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.createEncrypting),
              ],
            ),
          );
        }

        if (notifier.showResults) {
          return _ResultsView(notifier: notifier);
        }

        return _InputForm(notifier: notifier);
      },
    );
  }
}

class _InputForm extends StatefulWidget {
  final CreateNotifier notifier;

  const _InputForm({required this.notifier});

  @override
  State<_InputForm> createState() => _InputFormState();
}

class _InputFormState extends State<_InputForm> {
  late final TextEditingController _shardsController;
  late final TextEditingController _requiredController;

  @override
  void initState() {
    super.initState();
    _shardsController = TextEditingController(
      text: widget.notifier.totalShards.toString(),
    );
    _requiredController = TextEditingController(
      text: widget.notifier.requiredShards.toString(),
    );
  }

  @override
  void dispose() {
    _shardsController.dispose();
    _requiredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.notifier;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: notifier.updateTitle,
            decoration: InputDecoration(
              labelText: l10n.createTitleLabel,
              border: const OutlineInputBorder(),
              hintText: l10n.createTitleHint,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: notifier.updateSecret,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.createSecretLabel,
              border: const OutlineInputBorder(),
              hintText: l10n.createSecretHint,
              errorText: notifier.secretTooLong
                  ? l10n.createSecretTooLong
                  : null,
              helperText: notifier.secret.length > 900
                  ? l10n.createSecretCharCount(notifier.secret.length)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _shardsController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      notifier.updateTotalShards(parsed);
                      // Update required field if it was auto-clamped
                      final reqText = notifier.requiredShards.toString();
                      if (_requiredController.text != reqText) {
                        _requiredController.text = reqText;
                      }
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.createTotalShardsLabel,
                    border: const OutlineInputBorder(),
                    hintText: l10n.createTotalShardsHint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _requiredController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      notifier.updateRequiredShards(parsed);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.createRequiredLabel,
                    border: const OutlineInputBorder(),
                    hintText: l10n.createRequiredHint(notifier.totalShards),
                  ),
                ),
              ),
            ],
          ),
          if (notifier.totalShards >= 3 && notifier.requiredShards >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.createQuorumHelper(notifier.requiredShards, notifier.totalShards),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          PassphraseField(
            passphrase: notifier.passphrase,
            isManual: notifier.useManualPassphrase,
            onChanged: notifier.updatePassphrase,
            onRegenerate: notifier.regeneratePassphrase,
            onToggleMode: notifier.toggleManualPassphrase,
          ),
          if (notifier.error != null) ...[
            const SizedBox(height: 12),
            Text(
              notifier.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: notifier.canGenerate ? notifier.generate : null,
            child: Text(l10n.createGenerateButton),
          ),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final CreateNotifier notifier;

  const _ResultsView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.createSavePassphrase,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    notifier.passphrase,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.createPassphraseNeeded,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: notifier.backToEdit,
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.createBack),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.save_alt),
                tooltip: l10n.createSaveAllTooltip,
                onPressed: () async {
                  try {
                    final l10n = AppLocalizations.of(context)!;
                    final path = await ExportService.saveAsPdf(
                      shardJsons: notifier.generatedShards,
                      title: notifier.title,
                      requiredShards: notifier.requiredShards,
                      shardLabelBuilder: (index, total) =>
                          l10n.pdfShardLabel(index, total),
                      requiresLabel: l10n.pdfRequiresShards(notifier.requiredShards),
                      passphrasePlaceholder: l10n.pdfPassphrasePlaceholder,
                      languageCode: Localizations.localeOf(context).languageCode,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.createSavedTo(path))),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorSaving(e.toString()))),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: l10n.createShareAllTooltip,
                onPressed: () async {
                  try {
                    await ExportService.shareShards(
                      shardJsons: notifier.generatedShards,
                      title: notifier.title,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorSharing(e.toString()))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          QrGrid(
            shardJsons: notifier.generatedShards,
            title: notifier.title,
          ),
        ],
      ),
    );
  }
}
