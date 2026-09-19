import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

/// What happened when the system was asked to open a file.
enum OpenOutcome { opened, noApp, failed }

/// Seam over `OpenFilex.open`, so the outcome mapping is testable without a
/// platform channel.
typedef FileOpener = Future<OpenResult> Function(String path, {String? type});

/// Seam over `FilePicker.platform.saveFile`. Resolves to null when the picker
/// was dismissed.
typedef FileSaver = Future<String?> Function({
  String? fileName,
  Uint8List? bytes,
});

/// Seam over `Share.shareXFiles`.
typedef FileSharer = Future<void> Function(List<XFile> files);

/// Gets exported shards out of the app's own `banana_split/` directory — on
/// Android that is app-private storage no other app can see: open them in
/// place with a viewer, copy them somewhere the user picks, or share them.
///
/// Every file handed to another app carries an explicit MIME type
/// ([mimeTypeFor]). Without it Android's ContentResolver reports
/// `application/octet-stream`: the `ACTION_VIEW` chooser offers nothing
/// useful and strict share targets refuse the file.
class FileActionsService {
  FileActionsService({
    FileOpener? opener,
    FileSaver? saver,
    FileSharer? sharer,
    bool? pickerWritesBytes,
  })  : _opener = opener ?? _platformOpen,
        _saver = saver ?? _platformSave,
        _sharer = sharer ?? _platformShare,
        _pickerWritesBytes =
            pickerWritesBytes ?? (Platform.isAndroid || Platform.isIOS);

  final FileOpener _opener;
  final FileSaver _saver;
  final FileSharer _sharer;

  /// file_picker's `saveFile` is two different things. On Android/iOS it
  /// writes `bytes` to whatever the user picked (a content URI we could not
  /// write ourselves). On desktop it IGNORES `bytes` and merely returns the
  /// chosen path — the caller has to write the file.
  final bool _pickerWritesBytes;

  static Future<OpenResult> _platformOpen(String path, {String? type}) =>
      OpenFilex.open(path, type: type);

  static Future<String?> _platformSave({String? fileName, Uint8List? bytes}) =>
      FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);

  static Future<void> _platformShare(List<XFile> files) =>
      Share.shareXFiles(files);

  /// The app writes PDFs and PNGs only, so the table is closed on purpose —
  /// no `mime` dependency for two extensions.
  static String mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  /// Open [filePath] with whatever app handles its type.
  Future<OpenOutcome> openFile(String filePath) async {
    try {
      final result = await _opener(filePath, type: mimeTypeFor(filePath));
      return switch (result.type) {
        ResultType.done => OpenOutcome.opened,
        ResultType.noAppToOpen => OpenOutcome.noApp,
        _ => OpenOutcome.failed,
      };
    } catch (_) {
      return OpenOutcome.failed;
    }
  }

  /// Let the user copy [filePath] somewhere other apps can reach, through the
  /// system "save as" picker (Downloads by default on Android). Needs no
  /// storage permission. Returns false when the picker was dismissed.
  Future<bool> exportFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final target = await _saver(
      fileName: File(filePath).uri.pathSegments.last,
      bytes: bytes,
    );
    if (target == null) return false;
    if (!_pickerWritesBytes) await File(target).writeAsBytes(bytes);
    return true;
  }

  /// Hand [filePath] to the system share sheet, typed.
  Future<void> shareFile(String filePath) =>
      _sharer([XFile(filePath, mimeType: mimeTypeFor(filePath))]);
}
