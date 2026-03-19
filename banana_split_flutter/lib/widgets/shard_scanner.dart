import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';
import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
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
  // mobile_scanner (Android/iOS/macOS)
  MobileScannerController? _mobileController;

  // camera package (Windows)
  cam.CameraController? _winCameraController;
  Timer? _scanTimer;
  bool _isScanning = false;

  bool _cameraSupported = false;
  bool _permissionDenied = false;
  bool _disposed = false;
  bool _isPickingFile = false;
  final Set<String> _seenCodes = {};
  DateTime _lastScanTime = DateTime(0);

  bool get _useWindowsCamera => Platform.isWindows;

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
    if (_disposed || _isPickingFile) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeCamera();
        break;
      case AppLifecycleState.resumed:
        if (_cameraSupported || (!_permissionDenied && _mobileController == null && _winCameraController == null)) {
          _initCamera();
        }
        break;
      default:
        break;
    }
  }

  void _disposeCamera() {
    _scanTimer?.cancel();
    _scanTimer = null;

    if (_useWindowsCamera) {
      try {
        _winCameraController?.dispose();
      } catch (_) {}
      _winCameraController = null;
    } else {
      try {
        _mobileController?.stop().catchError((_) {});
        _mobileController?.dispose();
      } catch (_) {}
      _mobileController = null;
    }

    if (!_disposed && mounted) {
      setState(() => _cameraSupported = false);
    }
  }

  Future<void> _initCamera() async {
    if (_disposed) return;

    if (_useWindowsCamera) {
      await _initWindowsCamera();
    } else {
      await _initMobileCamera();
    }
  }

  Future<void> _initWindowsCamera() async {
    try {
      final cameras = await cam.availableCameras();
      if (_disposed) return;
      if (cameras.isEmpty) return;

      final controller = cam.CameraController(
        cameras.first,
        cam.ResolutionPreset.medium,
        enableAudio: false,
      );
      if (_disposed) {
        controller.dispose();
        return;
      }

      _winCameraController = controller;
      await controller.initialize();
      if (_disposed) {
        controller.dispose();
        _winCameraController = null;
        return;
      }

      if (mounted) setState(() => _cameraSupported = true);
      _startPeriodicScanning();
    } catch (e) {
      debugPrint('Windows camera init error: $e');
      _winCameraController?.dispose();
      _winCameraController = null;
    }
  }

  void _startPeriodicScanning() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _captureAndDecode();
    });
  }

  Future<void> _captureAndDecode() async {
    if (_disposed || _isScanning || _winCameraController == null) return;
    if (!_winCameraController!.value.isInitialized) return;

    _isScanning = true;
    try {
      final xFile = await _winCameraController!.takePicture();
      if (_disposed) return;
      final decoded = await _decodeQrWithZxing(xFile.path);
      // Clean up temp file
      try { await File(xFile.path).delete(); } catch (_) {}
      if (_disposed) return;
      if (decoded != null) {
        _onQrDetected(decoded);
      }
    } catch (e) {
      debugPrint('Windows capture error: $e');
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _initMobileCamera() async {
    if (Platform.isAndroid || Platform.isMacOS) {
      final status = await Permission.camera.request();
      if (_disposed) return;
      if (!status.isGranted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
    }

    try {
      final controller = MobileScannerController();
      if (_disposed) {
        controller.dispose();
        return;
      }
      _mobileController = controller;
      await controller.start();
      if (_disposed) {
        controller.dispose();
        _mobileController = null;
        return;
      }
      if (mounted) setState(() => _cameraSupported = true);
    } catch (_) {
      _mobileController?.dispose();
      _mobileController = null;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_disposed) return;

    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 500) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      if (_seenCodes.contains(raw)) continue;

      _seenCodes.add(raw);
      _lastScanTime = now;
      widget.onScanned(raw);
    }
  }

  void _onQrDetected(String raw) {
    if (_disposed) return;
    if (raw.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 500) return;
    if (_seenCodes.contains(raw)) return;

    _seenCodes.add(raw);
    _lastScanTime = now;
    widget.onScanned(raw);
  }

  Future<String?> _getInitialDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bsDir = '${dir.path}/banana_split';
      if (await Directory(bsDir).exists()) return bsDir;
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _importFromGallery() async {
    _isPickingFile = true;

    // Pause periodic scanning while file picker is open
    _scanTimer?.cancel();

    try {
      String? filePath;

      if (Platform.isWindows) {
        // Use FilePicker on Windows — supports initialDirectory
        final initialDir = await _getInitialDirectory();
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          initialDirectory: initialDir,
        );
        if (result == null || result.files.isEmpty || _disposed) return;
        filePath = result.files.first.path;
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
        if (picked == null || _disposed) return;
        filePath = picked.path;
      }

      if (filePath == null || _disposed) return;

      // Try mobile_scanner's image analysis first (works best on mobile)
      if (_mobileController != null) {
        try {
          final capture = await _mobileController!.analyzeImage(filePath);
          if (capture != null && capture.barcodes.isNotEmpty) {
            _onDetect(capture);
            return;
          }
        } catch (_) {
          // analyzeImage may not be supported on all platforms
        }
      }

      // Fallback: decode with zxing2 (pure Dart, works on all platforms)
      final decoded = await _decodeQrWithZxing(filePath);
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
    } finally {
      _isPickingFile = false;
      // Resume periodic scanning if camera is still active
      if (_useWindowsCamera && _winCameraController != null && !_disposed) {
        _startPeriodicScanning();
      }
    }
  }

  Future<String?> _decodeQrWithZxing(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Convert to luminance source for zxing2
      // Use normalized accessors (0.0-1.0) to handle any bit depth
      final width = decoded.width;
      final height = decoded.height;
      final pixels = Int32List(width * height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = decoded.getPixel(x, y);
          final r = (pixel.rNormalized * 255).round();
          final g = (pixel.gNormalized * 255).round();
          final b = (pixel.bNormalized * 255).round();
          final a = (pixel.aNormalized * 255).round();
          pixels[y * width + x] = (a << 24) | (r << 16) | (g << 8) | b;
        }
      }

      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));

      final hints = DecodeHints();
      hints.put(DecodeHintType.tryHarder);

      final result = QRCodeReader().decode(bitmap, hints: hints);
      return result.text;
    } catch (e) {
      debugPrint('QR decode error: $e');
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

        if (_cameraSupported)
          _buildCameraPreview()
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

  Widget _buildCameraPreview() {
    if (_useWindowsCamera && _winCameraController != null) {
      return SizedBox(
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: cam.CameraPreview(_winCameraController!),
        ),
      );
    }

    if (_mobileController != null) {
      return SizedBox(
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MobileScanner(
            controller: _mobileController!,
            onDetect: _onDetect,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
