import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:banana_split_flutter/state/restore_notifier.dart';
import 'package:banana_split_flutter/widgets/shard_scanner.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RestoreNotifier>(
      builder: (context, notifier, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                notifier.title.isNotEmpty
                    ? 'Combine shards for "${notifier.title}"'
                    : 'Combine shards',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              if (notifier.recoveredSecret != null)
                _RecoveredView(notifier: notifier)
              else if (notifier.needMoreShards)
                _ScannerView(notifier: notifier)
              else
                _PassphraseView(notifier: notifier),

              const SizedBox(height: 16),

              if (notifier.scannedCount > 0 || notifier.recoveredSecret != null)
                OutlinedButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Start over'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({required this.notifier});

  final RestoreNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ShardScanner(
      scannedCount: notifier.scannedCount,
      requiredCount: notifier.requiredCount > 0 ? notifier.requiredCount : null,
      onScanned: (rawData) {
        final error = notifier.addShard(rawData);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shard ${notifier.scannedCount} of '
                '${notifier.requiredCount} scanned',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
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
    final notifier = widget.notifier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'All shards collected!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Passphrase',
            border: OutlineInputBorder(),
            hintText: 'Enter passphrase to decrypt',
          ),
          obscureText: true,
          onSubmitted: (_) => _submit(),
          onChanged: notifier.updatePassphrase,
          enabled: !notifier.isDecrypting,
        ),
        if (notifier.error != null) ...[
          const SizedBox(height: 8),
          Text(
            notifier.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        if (notifier.isDecrypting)
          const Center(child: CircularProgressIndicator())
        else
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Reconstruct Secret'),
          ),
        if (notifier.isDecrypting) ...[
          const SizedBox(height: 8),
          const Center(child: Text('Decrypting...')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recovered Secret',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
