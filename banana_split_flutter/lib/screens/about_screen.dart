import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About Banana Split', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Banana Split lets you securely split a secret — such as a password, '
            'seed phrase, or private key — into multiple shards using '
            "Shamir's Secret Sharing.",
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text("What is Shamir's Secret Sharing?",
              style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            "Shamir's Secret Sharing (SSS) is a cryptographic algorithm invented by "
            'Adi Shamir in 1979. It divides a secret into N pieces (shards) such that '
            'any K of them (the threshold) are sufficient to reconstruct the original '
            'secret, but K-1 or fewer shards reveal nothing about the secret.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('How Banana Split works', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '1. You enter a secret and a passphrase.\n'
            '2. The secret is encrypted with your passphrase using NaCl secretbox '
            '(XSalsa20-Poly1305).\n'
            '3. The encrypted data is split into N shards using Shamir\'s Secret '
            'Sharing over GF(256).\n'
            '4. Each shard is encoded as a QR code that you can print or distribute '
            'to trusted custodians.\n'
            '5. To recover the secret, you scan at least K shards and enter the '
            'passphrase. The shards are recombined and the data is decrypted.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Security notes', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '- All cryptographic operations happen on-device. No data is ever '
            'transmitted to a server.\n'
            '- The passphrase adds an additional layer of protection: even if '
            'enough shards are compromised, the attacker still needs the passphrase '
            'to decrypt the secret.\n'
            '- Store shards separately and in physically secure locations.',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
