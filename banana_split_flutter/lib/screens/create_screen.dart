import 'package:flutter/material.dart';
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
        if (notifier.isGenerating) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Encrypting...'),
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

  @override
  void initState() {
    super.initState();
    _shardsController = TextEditingController(
      text: widget.notifier.totalShards.toString(),
    );
  }

  @override
  void dispose() {
    _shardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.notifier;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: notifier.updateTitle,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              hintText: 'e.g. My wallet seed phrase',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: notifier.updateSecret,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Secret',
              border: const OutlineInputBorder(),
              hintText: 'Enter the secret to split',
              errorText: notifier.secretTooLong
                  ? 'Secret exceeds 1024 characters'
                  : null,
              helperText: notifier.secret.length > 900
                  ? '${notifier.secret.length}/1024 characters'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _shardsController,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                notifier.updateTotalShards(parsed);
              }
            },
            decoration: InputDecoration(
              labelText: 'Number of shards',
              border: const OutlineInputBorder(),
              hintText: '3–255',
              helperText: notifier.totalShards >= 3
                  ? 'Requires ${notifier.requiredShards} of ${notifier.totalShards} shards to restore'
                  : 'Minimum 3 shards',
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
            child: const Text('Generate QR Shards'),
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
                        'Save your passphrase!',
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
                    'You will need this passphrase to restore your secret.',
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
                label: const Text('Back'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.save_alt),
                tooltip: 'Save all shards',
                onPressed: () async {
                  try {
                    final path = await ExportService.saveAsPdf(
                      shardJsons: notifier.generatedShards,
                      title: notifier.title,
                      requiredShards: notifier.requiredShards,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved to $path')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving: $e')),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share all shards',
                onPressed: () async {
                  try {
                    await ExportService.shareShards(
                      shardJsons: notifier.generatedShards,
                      title: notifier.title,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error sharing: $e')),
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
