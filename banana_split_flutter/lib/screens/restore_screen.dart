import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:banana_split_flutter/state/restore_notifier.dart';
import 'package:banana_split_flutter/widgets/shard_scanner.dart';

String _localizeError(AppLocalizations l10n, ShardError error) {
  return switch (error) {
    EmptyQrError() => l10n.errorEmptyQr,
    DuplicateShardError() => l10n.errorDuplicateShard,
    ParseError(:final detail) => l10n.errorParseFailed(detail),
    TitleMismatchError(:final expected, :final actual) =>
      l10n.errorTitleMismatch(expected, actual),
    NonceMismatchError() => l10n.errorNonceMismatch,
    RequiredMismatchError() => l10n.errorRequiredMismatch,
    VersionMismatchError() => l10n.errorVersionMismatch,
    DecryptionError() => l10n.errorDecryptionFailed,
    NotEnoughShardsError(:final required, :final got) =>
      l10n.errorNotEnoughShards(required, got),
  };
}

class RestoreScreen extends StatelessWidget {
  final bool isActive;

  const RestoreScreen({super.key, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<RestoreNotifier>(
      builder: (context, notifier, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                notifier.title.isNotEmpty
                    ? l10n.restoreCombineTitle(notifier.title)
                    : l10n.restoreCombineTitleDefault,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              if (notifier.recoveredSecret != null)
                _RecoveredView(notifier: notifier)
              else if (notifier.needMoreShards)
                _ScannerView(notifier: notifier, isActive: isActive)
              else
                _PassphraseView(notifier: notifier),

              const SizedBox(height: 16),

              if (notifier.scannedCount > 0 || notifier.recoveredSecret != null)
                OutlinedButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.restoreStartOver),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({required this.notifier, this.isActive = true});

  final RestoreNotifier notifier;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ShardScanner(
      isActive: isActive,
      scannedCount: notifier.scannedCount,
      requiredCount: notifier.requiredCount > 0 ? notifier.requiredCount : null,
      onScanned: (rawData, {isBatch = false}) {
        final error = notifier.addShard(rawData);
        if (!isBatch) {
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_localizeError(l10n, error))),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.restoreShardScanned(
                    notifier.scannedCount,
                    notifier.requiredCount,
                  ),
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
        return error;
      },
    );
  }
}

class _PassphraseView extends StatefulWidget {
  const _PassphraseView({required this.notifier});

  final RestoreNotifier notifier;

  @override
  State<_PassphraseView> createState() => _PassphraseViewState();
}

class _PassphraseViewState extends State<_PassphraseView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.notifier.updatePassphrase(_controller.text);
    widget.notifier.reconstruct();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = widget.notifier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.restoreAllCollected,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.restorePassphraseLabel,
            border: const OutlineInputBorder(),
            hintText: l10n.restorePassphraseHint,
          ),
          obscureText: true,
          onSubmitted: (_) => _submit(),
          onChanged: notifier.updatePassphrase,
          enabled: !notifier.isDecrypting,
        ),
        if (notifier.error != null) ...[
          const SizedBox(height: 8),
          Text(
            _localizeError(l10n, notifier.error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        if (notifier.isDecrypting)
          const Center(child: CircularProgressIndicator())
        else
          ElevatedButton(
            onPressed: _submit,
            child: Text(l10n.restoreReconstructButton),
          ),
        if (notifier.isDecrypting) ...[
          const SizedBox(height: 8),
          Center(child: Text(l10n.restoreDecrypting)),
        ],
      ],
    );
  }
}

class _RecoveredView extends StatelessWidget {
  const _RecoveredView({required this.notifier});

  final RestoreNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.restoreRecoveredSecret,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              notifier.recoveredSecret!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
