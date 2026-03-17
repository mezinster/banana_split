import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:banana_split_flutter/services/export_service.dart';

class QrGrid extends StatelessWidget {
  final List<String> shardJsons;
  final String title;

  const QrGrid({super.key, required this.shardJsons, required this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: shardJsons.length,
      itemBuilder: (context, index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(l10n.shardLabel(index + 1, shardJsons.length),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Expanded(
                  child: QrImageView(
                    data: shardJsons[index],
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_alt, size: 18),
                      tooltip: l10n.shardSaveTooltip,
                      onPressed: () async {
                        try {
                          await ExportService.saveSinglePng(
                            shardJson: shardJsons[index],
                            title: title,
                            shardIndex: index + 1,
                          );
                          if (context.mounted) {
                            final l10n = AppLocalizations.of(context)!;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.shardSaved)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            final l10n = AppLocalizations.of(context)!;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.errorSaving(e.toString()))),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 18),
                      tooltip: l10n.shardShareTooltip,
                      onPressed: () async {
                        try {
                          await ExportService.shareSingleShard(
                            shardJson: shardJsons[index],
                            title: title,
                            shardIndex: index + 1,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            final l10n = AppLocalizations.of(context)!;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.errorSharing(e.toString()))),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
