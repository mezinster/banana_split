import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ExportService {
  ExportService._();

  static Future<Uint8List> _qrToPng(String data, {int size = 300}) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    );
    final image = await qrPainter.toImage(size.toDouble());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<String> saveAsPngs({
    required List<String> shardJsons,
    required String title,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split/$safeTitle');
    await subDir.create(recursive: true);

    for (int i = 0; i < shardJsons.length; i++) {
      final pngBytes = await _qrToPng(shardJsons[i]);
      final file = File('${subDir.path}/${safeTitle}_shard_${i + 1}.png');
      await file.writeAsBytes(pngBytes);
    }
    return subDir.path;
  }

  static Future<String> saveSinglePng({
    required String shardJson,
    required String title,
    required int shardIndex,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split/$safeTitle');
    await subDir.create(recursive: true);

    final pngBytes = await _qrToPng(shardJson);
    final file = File('${subDir.path}/${safeTitle}_shard_$shardIndex.png');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  static Future<String> saveAsPdf({
    required List<String> shardJsons,
    required String title,
    required int requiredShards,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split');
    await subDir.create(recursive: true);

    final pdf = pw.Document();

    for (int i = 0; i < shardJsons.length; i++) {
      final pngBytes = await _qrToPng(shardJsons[i], size: 300);
      final image = pw.MemoryImage(pngBytes);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Shard ${i + 1} of ${shardJsons.length}', style: const pw.TextStyle(fontSize: 18)),
              pw.Text('Requires $requiredShards shards to reconstruct', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 24),
              pw.Image(image, width: 300, height: 300),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                child: pw.Text('Write your passphrase here: ___________________________',
                    style: const pw.TextStyle(fontSize: 16)),
              ),
            ],
          ));
        },
      ));
    }

    final filePath = '${subDir.path}/${safeTitle}_shards.pdf';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  static Future<void> shareShards({
    required List<String> shardJsons,
    required String title,
  }) async {
    final dirPath = await saveAsPngs(shardJsons: shardJsons, title: title);
    final dir = Directory(dirPath);
    final files = await dir.list().where((f) => f.path.endsWith('.png')).toList();
    final xFiles = files.map((f) => XFile(f.path)).toList();
    await Share.shareXFiles(xFiles, subject: 'Banana Split: $title');
  }

  static Future<void> shareSingleShard({
    required String shardJson,
    required String title,
    required int shardIndex,
  }) async {
    final path = await saveSinglePng(shardJson: shardJson, title: title, shardIndex: shardIndex);
    await Share.shareXFiles([XFile(path)], subject: 'Banana Split: $title - Shard $shardIndex');
  }
}
