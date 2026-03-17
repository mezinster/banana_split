import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _privacyUrl =
      'https://github.com/mezinster/banana_split/blob/master/PRIVACY_POLICY.md';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicyTitle),
        actions: [
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(_privacyUrl)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.privacyPolicyViewOnline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.privacyPolicyBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
