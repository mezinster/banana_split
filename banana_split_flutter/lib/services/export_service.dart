import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ExportService {
  ExportService._();

  static Future<Uint8List> _qrToPng(String data, {int size = 800}) async {
    // Pre-compute QR code to determine module count, then render at a size
    // that's an exact multiple of module count. This ensures integer pixel
    // sizes per module, preventing qr_flutter's 0.5px rounding from pushing
    // the QR outside image bounds and corrupting finder patterns.
    final validationResult = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final qrCode = validationResult.qrCode!;
    final moduleCount = qrCode.moduleCount;

    final maxQrArea = size - 2 * (size * 0.08).round();
    final modulePixels = maxQrArea ~/ moduleCount;
    final qrSize = modulePixels * moduleCount;
    final padding = (size - qrSize) ~/ 2;

    final qrPainter = QrPainter.withQr(
      qr: qrCode,
      gapless: true,
    );
    final qrImage = await qrPainter.toImage(qrSize.toDouble());

    // Composite onto white background with quiet zone
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawImage(
      qrImage,
      Offset(padding.toDouble(), padding.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<String> saveAsPngs({
    required List<String> shardJsons,
    required String title,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '').replaceAll(' ', '_');
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
    final safeTitle = title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '').replaceAll(' ', '_');
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
    required String Function(int index, int total) shardLabelBuilder,
    required String requiresLabel,
    required String passphrasePlaceholder,
    String languageCode = 'en',
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split');
    await subDir.create(recursive: true);

    // Load Unicode-compatible fonts for PDF rendering
    final pw.Font regularFont;
    final pw.Font boldFont;
    if (languageCode == 'ka') {
      final fontData = await rootBundle.load('assets/fonts/NotoSansGeorgian-Regular.ttf');
      regularFont = pw.Font.ttf(fontData);
      boldFont = regularFont; // No bold variant for Georgian
    } else {
      final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    }

    final pdf = pw.Document();

    for (int i = 0; i < shardJsons.length; i++) {
      final pngBytes = await _qrToPng(shardJsons[i], size: 800);
      final image = pw.MemoryImage(pngBytes);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 24, font: boldFont, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text(shardLabelBuilder(i + 1, shardJsons.length), style: pw.TextStyle(fontSize: 18, font: regularFont)),
              pw.Text(requiresLabel, style: pw.TextStyle(fontSize: 14, font: regularFont)),
              pw.SizedBox(height: 24),
              pw.Image(image, width: 300, height: 300),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                child: pw.Text(passphrasePlaceholder,
                    style: pw.TextStyle(fontSize: 16, font: regularFont)),
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
    final xFiles = files.map((f) => XFile(f.path, mimeType: 'image/png')).toList();
    await Share.shareXFiles(xFiles, subject: 'Banana Split: $title');
  }

  static Future<void> shareSingleShard({
    required String shardJson,
    required String title,
    required int shardIndex,
  }) async {
    final path = await saveSinglePng(shardJson: shardJson, title: title, shardIndex: shardIndex);
    await Share.shareXFiles([XFile(path, mimeType: 'image/png')], subject: 'Banana Split: $title - Shard $shardIndex');
  }
}
