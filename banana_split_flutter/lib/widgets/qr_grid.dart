import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGrid extends StatelessWidget {
  final List<String> shardJsons;
  final String title;

  const QrGrid({super.key, required this.shardJsons, required this.title});

  @override
  Widget build(BuildContext context) {
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
                Text('Shard ${index + 1} of ${shardJsons.length}',
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
                      tooltip: 'Save this shard',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Save coming soon')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 18),
                      tooltip: 'Share this shard',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share coming soon')),
                        );
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
