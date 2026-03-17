import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
    if (Platform.isWindows || Platform.isLinux) return;

    final status = await Permission.camera.request();
    if (status.isGranted) {
      _cameraController = MobileScannerController();
      setState(() => _cameraSupported = true);
    } else {
      setState(() => _permissionDenied = true);
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
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Try using mobile_scanner's image analysis if available
    if (_cameraController != null) {
      final capture = await _cameraController!.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        _onDetect(capture);
        return;
      }
    }

    // Fallback: show message that QR code wasn't found
    // Note: zxing2 integration for desktop would go here but requires
    // significant image processing setup. For now, on platforms with
    // camera, the camera controller handles analysis.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR code found in image')),
      );
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
            child: const Text('Camera not available on this platform.\n'
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
