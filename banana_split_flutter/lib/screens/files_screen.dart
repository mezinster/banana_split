import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => FilesScreenState();
}

class FilesScreenState extends State<FilesScreen> with WidgetsBindingObserver {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFiles();
    }
  }

  void refresh() => _loadFiles();

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bananaSplitDir = Directory('${dir.path}/banana_split');
      if (!await bananaSplitDir.exists()) {
        setState(() {
          _files = [];
          _loading = false;
        });
        return;
      }
      final entities = await bananaSplitDir
          .list(recursive: true)
          .where((e) =>
              e is File &&
              (e.path.endsWith('.png') || e.path.endsWith('.pdf')))
          .cast<File>()
          .toList();
      // Sort by last modified, newest first
      entities.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      setState(() {
        _files = entities;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _files = [];
        _loading = false;
      });
    }
  }

  String _humanFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _subtitle(File file) {
    final normalized = file.path.replaceAll('\\', '/');
    final bananaSplitIndex = normalized.indexOf('banana_split/');
    if (bananaSplitIndex == -1) return '';
    final relative = normalized.substring(bananaSplitIndex + 'banana_split/'.length);
    final parts = relative.split('/');
    if (parts.length > 1) return parts.first;
    return '';
  }

  Future<void> _shareFile(File file) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final mime = file.path.endsWith('.pdf') ? 'application/pdf' : 'image/png';
      await Share.shareXFiles([XFile(file.path, mimeType: mime)]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesShareError)),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesDeleteConfirmTitle),
        content: Text(l10n.filesDeleteConfirmBody(file.uri.pathSegments.last)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.filesCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.filesDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await file.delete();
      // Remove parent dir if empty
      final parent = file.parent;
      final remaining = await parent.list().toList();
      if (remaining.isEmpty) {
        await parent.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesDeleted)),
      );
      await _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesDeleteError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.filesEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final stat = file.statSync();
          final subtitle = _subtitle(file);
          final dateStr = DateFormat.yMMMd().format(stat.modified);
          final sizeStr = _humanFileSize(stat.size);
          return ListTile(
            leading: Icon(
              file.path.endsWith('.pdf')
                  ? Icons.picture_as_pdf
                  : Icons.image_outlined,
            ),
            title: Text(file.uri.pathSegments.last),
            subtitle: Text(
              subtitle.isEmpty
                  ? '$sizeStr · $dateStr'
                  : '$subtitle · $sizeStr · $dateStr',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareFile(file),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteFile(file),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
