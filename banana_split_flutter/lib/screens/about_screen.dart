import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:banana_split_flutter/screens/privacy_policy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.aboutHeading, style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(l10n.aboutDescription, style: textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text(l10n.aboutWhatIsSss, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutSssExplanation, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.aboutHowItWorks, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutHowItWorksBody, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.aboutSecurityNotes, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutSecurityNotesBody, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(
            l10n.aboutForkNotice('banana_split', 'Parity Technologies'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.aboutForkCopyright,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://github.com/paritytech/banana_split'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'github.com/paritytech/banana_split',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const Divider(height: 32),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final info = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.aboutVersion(info.version, info.buildNumber),
                  style: textTheme.bodySmall,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.aboutPrivacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: l10n.aboutVersion(info.version, info.buildNumber),
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/app_icon.png', width: 48, height: 48),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.aboutWebApp),
            subtitle: const Text('nfcarchiver.com/banana'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse('https://nfcarchiver.com/banana/'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.aboutSourceCode),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/mezinster/banana_split'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}
