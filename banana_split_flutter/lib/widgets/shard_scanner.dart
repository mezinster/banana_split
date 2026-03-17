import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zxing2/qrcode.dart';

class ShardScanner extends StatefulWidget {
  final void Function(String rawData) onScanned;
  final int scannedCount;
  final int? requiredCount;

  const ShardScanner({
    super.key,
    required this.onScanned,
    required this.scannedCount,
    this.requiredCount,
  });

  @override
  State<ShardScanner> createState() => _ShardScannerState();
}

class _ShardScannerState extends State<ShardScanner> {
  MobileScannerController? _cameraController;
  bool _cameraSupported = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // On mobile, request permission first
    if (Platform.isAndroid || Platform.isMacOS) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() => _permissionDenied = true);
        return;
      }
    }

    // Try to start the camera on all platforms
    try {
      _cameraController = MobileScannerController();
      await _cameraController!.start();
      if (mounted) setState(() => _cameraSupported = true);
    } catch (_) {
      // Camera not available — fall back to gallery import
      _cameraController?.dispose();
      _cameraController = null;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        widget.onScanned(raw);
      }
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Try mobile_scanner's image analysis first (works best on mobile)
    if (_cameraController != null) {
      final capture = await _cameraController!.analyzeImage(picked.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        _onDetect(capture);
        return;
      }
    }

    // Fallback: decode with zxing2 (pure Dart, works on all platforms)
    final decoded = await _decodeQrWithZxing(picked.path);
    if (decoded != null) {
      widget.onScanned(decoded);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR code found in image')),
      );
    }
  }

  Future<String?> _decodeQrWithZxing(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Convert to luminance source for zxing2
      final width = decoded.width;
      final height = decoded.height;
      final pixels = Int32List(width * height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = decoded.getPixel(x, y);
          pixels[y * width + x] =
              (pixel.a.toInt() << 24) |
              (pixel.r.toInt() << 16) |
              (pixel.g.toInt() << 8) |
              pixel.b.toInt();
        }
      }

      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      return result.text;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressText = widget.requiredCount != null
        ? '${widget.scannedCount} of ${widget.requiredCount} scanned'
        : 'Scan first shard...';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(progressText,
              style: Theme.of(context).textTheme.titleMedium),
        ),

        if (_cameraSupported && _cameraController != null)
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: _cameraController!,
                onDetect: _onDetect,
              ),
            ),
          )
        else if (_permissionDenied)
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Camera permission denied.\n'
                    'Grant camera access in Settings, or import QR images below.'),
                SizedBox(height: 8),
                TextButton(
                  onPressed: openAppSettings,
                  child: Text('Open Settings'),
                ),
              ],
            ),
          )
        else
          Container(
            height: 200,
            alignment: Alignment.center,
            child: const Text('Camera not available.\n'
                'Use the import button below to load QR code images.'),
          ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _importFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('Import from gallery'),
        ),
      ],
    );
  }
}
