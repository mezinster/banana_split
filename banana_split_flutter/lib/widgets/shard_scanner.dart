import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

class _ShardScannerState extends State<ShardScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _cameraController;
  bool _cameraSupported = false;
  bool _permissionDenied = false;
  bool _disposed = false;
  final Set<String> _seenCodes = {};
  DateTime _lastScanTime = DateTime(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // Android reclaims camera when app goes to background
        _disposeCamera();
        break;
      case AppLifecycleState.resumed:
        // Re-init camera when app returns to foreground
        if (_cameraSupported || (!_permissionDenied && _cameraController == null)) {
          _initCamera();
        }
        break;
      default:
        break;
    }
  }

  void _disposeCamera() {
    try {
      _cameraController?.stop().catchError((_) {});
      _cameraController?.dispose();
    } catch (_) {
      // Ignore errors during cleanup
    }
    _cameraController = null;
    if (!_disposed && mounted) {
      setState(() => _cameraSupported = false);
    }
  }

  Future<void> _initCamera() async {
    if (_disposed) return;

    // On mobile, request permission first
    if (Platform.isAndroid || Platform.isMacOS) {
      final status = await Permission.camera.request();
      if (_disposed) return;
      if (!status.isGranted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
    }

    // Try to start the camera on all platforms
    try {
      final controller = MobileScannerController();
      if (_disposed) {
        controller.dispose();
        return;
      }
      _cameraController = controller;
      await controller.start();
      if (_disposed) {
        controller.dispose();
        _cameraController = null;
        return;
      }
      if (mounted) setState(() => _cameraSupported = true);
    } catch (_) {
      // Camera not available — fall back to gallery import
      _cameraController?.dispose();
      _cameraController = null;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_disposed) return;

    // Throttle: ignore detections within 500ms of the last successful scan
    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 500) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      // Skip codes we've already forwarded
      if (_seenCodes.contains(raw)) continue;

      _seenCodes.add(raw);
      _lastScanTime = now;
      widget.onScanned(raw);
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || _disposed) return;

    // Try mobile_scanner's image analysis first (works best on mobile)
    if (_cameraController != null) {
      try {
        final capture = await _cameraController!.analyzeImage(picked.path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          _onDetect(capture);
          return;
        }
      } catch (_) {
        // analyzeImage may not be supported on all platforms
      }
    }

    // Fallback: decode with zxing2 (pure Dart, works on all platforms)
    final decoded = await _decodeQrWithZxing(picked.path);
    if (_disposed) return;
    if (decoded != null) {
      widget.onScanned(decoded);
      return;
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerNoQrFound)),
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
    final l10n = AppLocalizations.of(context)!;
    final progressText = widget.requiredCount != null
        ? l10n.scannerProgress(widget.scannedCount, widget.requiredCount!)
        : l10n.scannerScanFirst;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.scannerCameraDenied),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: openAppSettings,
                  child: Text(l10n.scannerOpenSettings),
                ),
              ],
            ),
          )
        else
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(l10n.scannerCameraUnavailable),
          ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _importFromGallery,
          icon: const Icon(Icons.photo_library),
          label: Text(l10n.scannerImportGallery),
        ),
      ],
    );
  }
}
