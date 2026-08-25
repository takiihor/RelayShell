import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/ssh/sftp_service.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import 'file_viewer_screen.dart';
import 'transfer_sheet.dart';

/// The SFTP file browser (SPEC 15).
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({
    required this.hostId,
    super.key,
    this.initialPath,
    this.projectId,
  });

  final String hostId;
  final String? initialPath;
  final String? projectId;

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  SshConnection? _connection;
  String? _path;
  List<RemoteFile>? _entries;
  Object? _error;
  bool _loading = true;
  bool _showHidden = false;
  _SortBy _sortBy = _SortBy.name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final host = await ref.read(hostsRepositoryProvider).byId(widget.hostId);
      if (host == null) throw StateError('Host not found');

      final connection = await ref
          .read(connectionManagerProvider)
          .connect(host);
      final sftp = ref.read(sftpServiceProvider);

      // A project path may be `~/…`, which SFTP does not expand; resolving
      // through the server gives an absolute path that navigation can rely on.
      final target = widget.initialPath ?? host.startupDirectory ?? '.';
      final resolved = await sftp.resolve(
        connection,
        target.startsWith('~/')
            ? '${await sftp.homeDirectory(connection)}${target.substring(1)}'
            : target,
      );

      _connection = connection;
      await _navigate(resolved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _navigate(String path) async {
    final connection = _connection;
    if (connection == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await ref
          .read(sftpServiceProvider)
          .list(connection, path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<RemoteFile> get _visibleEntries {
    final entries = _entries ?? const <RemoteFile>[];
    final filtered = _showHidden
        ? entries
        : entries.where((e) => !e.isHidden).toList();

    final sorted = [...filtered];
    sorted.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return switch (_sortBy) {
        _SortBy.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _SortBy.size => (b.size ?? 0).compareTo(a.size ?? 0),
        _SortBy.modified => (b.modified ?? DateTime(1970)).compareTo(
          a.modified ?? DateTime(1970),
        ),
      };
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = _path;
    final parent = path == null ? null : SftpService.parentOf(path);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.filesTitle),
            if (path != null)
              Text(
                shortenPath(path, maxLength: 46),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.actionRefresh,
            onPressed: path == null ? null : () => _navigate(path),
          ),
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'hidden',
                checked: _showHidden,
                child: Text(l10n.filesShowHidden),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'sort_name',
                checked: _sortBy == _SortBy.name,
                child: Text(l10n.filesSortName),
              ),
              CheckedPopupMenuItem(
                value: 'sort_size',
                checked: _sortBy == _SortBy.size,
                child: Text(l10n.filesSortSize),
              ),
              CheckedPopupMenuItem(
                value: 'sort_modified',
                checked: _sortBy == _SortBy.modified,
                child: Text(l10n.filesSortModified),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'mkdir', child: Text(l10n.actionNewFolder)),
              PopupMenuItem(value: 'upload', child: Text(l10n.actionUpload)),
              PopupMenuItem(
                value: 'copy_path',
                child: Text(l10n.actionCopyPath),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context, parent),
    );
  }

  Widget _buildBody(BuildContext context, String? parent) {
    final l10n = AppLocalizations.of(context);

    if (_loading && _entries == null) return const LoadingView();

    final error = _error;
    if (error != null && _entries == null) {
      return FailureView(
        failure: error is SshFailure
            ? error
            : SshFailure(
                kind: SshFailureKind.unknown,
                message: l10n.filesLoadFailed,
                technicalDetail: error.toString(),
              ),
        onRetry: _open,
      );
    }

    final entries = _visibleEntries;

    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (parent != null)
          ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_upward),
            title: Text(l10n.filesParent),
            onTap: () => _navigate(parent),
          ),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: l10n.filesEmptyFolder,
                  body: l10n.filesItemCount(0),
                  actionLabel: l10n.actionUpload,
                  onAction: _upload,
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _FileTile(
                    file: entries[index],
                    onTap: () => _onEntryTap(entries[index]),
                    onLongPress: () => _showEntryMenu(entries[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _onEntryTap(RemoteFile file) async {
    if (file.isDirectory) {
      await _navigate(file.path);
      return;
    }
    await _openFile(file);
  }

  Future<void> _openFile(RemoteFile file) async {
    final connection = _connection;
    if (connection == null) return;

    final size = file.size ?? 0;
    if (size > SftpService.maxViewableBytes) {
      if (!mounted) return;
      showMessage(context, AppLocalizations.of(context).filesTooLargeToView);
      await _download(file);
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            FileViewerScreen(connection: connection, file: file),
      ),
    );
  }

  Future<void> _showEntryMenu(RemoteFile file) async {
    final l10n = AppLocalizations.of(context);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                file.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!file.isDirectory)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.actionDownload),
                onTap: () => Navigator.of(context).pop('download'),
              ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.actionRename),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.actionCopyPath),
              onTap: () => Navigator.of(context).pop('copy_path'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.actionDelete),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'download':
        await _download(file);
      case 'rename':
        await _rename(file);
      case 'copy_path':
        await Clipboard.setData(ClipboardData(text: file.path));
        if (mounted) showMessage(context, l10n.filesPathCopied);
      case 'delete':
        await _delete(file);
    }
  }

  Future<void> _onMenu(String value) async {
    switch (value) {
      case 'hidden':
        setState(() => _showHidden = !_showHidden);
      case 'sort_name':
        setState(() => _sortBy = _SortBy.name);
      case 'sort_size':
        setState(() => _sortBy = _SortBy.size);
      case 'sort_modified':
        setState(() => _sortBy = _SortBy.modified);
      case 'mkdir':
        await _createFolder();
      case 'upload':
        await _upload();
      case 'copy_path':
        final path = _path;
        if (path == null) return;
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          showMessage(context, AppLocalizations.of(context).filesPathCopied);
        }
    }
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context);
    final connection = _connection;
    final path = _path;
    if (connection == null || path == null) return;

    final name = await _askText(
      context,
      title: l10n.filesNewFolderTitle,
      hint: l10n.filesNewFolderHint,
    );
    if (name == null || !mounted) return;

    try {
      await ref
          .read(sftpServiceProvider)
          .createDirectory(connection, SftpService.joinPath(path, name));
      await _navigate(path);
    } on FileOperationException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    }
  }

  Future<void> _rename(RemoteFile file) async {
    final l10n = AppLocalizations.of(context);
    final connection = _connection;
    final path = _path;
    if (connection == null || path == null) return;

    final name = await _askText(
      context,
      title: l10n.filesRenameTitle,
      hint: l10n.filesNewFolderHint,
      initial: file.name,
    );
    if (name == null || name == file.name || !mounted) return;

    try {
      await ref
          .read(sftpServiceProvider)
          .rename(connection, file.path, SftpService.joinPath(path, name));
      await _navigate(path);
    } on FileOperationException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    }
  }

  /// Deletes a file or folder, naming the scope precisely (SPEC 15.2).
  Future<void> _delete(RemoteFile file) async {
    final l10n = AppLocalizations.of(context);
    final connection = _connection;
    final path = _path;
    if (connection == null || path == null) return;

    final service = ref.read(sftpServiceProvider);

    if (!file.isDirectory) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.filesDeleteFileTitle,
        body: '${file.name}\n${l10n.confirmCannotUndo}',
      );
      if (!confirmed) return;
      try {
        await service.deleteFile(connection, file.path);
        await _navigate(path);
      } on FileOperationException catch (error) {
        if (mounted) showMessage(context, error.message, isError: true);
      }
      return;
    }

    // Counting first turns "delete this folder" into a decision the user can
    // actually weigh, rather than a blind yes (SPEC 15.2).
    int? count;
    try {
      count = await service.countEntries(connection, file.path);
    } on FileOperationException {
      count = null;
    }
    if (!mounted) return;

    final confirmed = await confirmDestructive(
      context,
      title: l10n.filesDeleteFolderTitle,
      body: [
        l10n.filesDeleteFolderBody(file.name),
        if (count != null) l10n.filesDeleteFolderCount(count),
      ].join('\n\n'),
      confirmLabel: l10n.filesDeleteRecursive,
    );
    if (!confirmed) return;

    try {
      await service.deleteRecursively(connection, file.path);
      await _navigate(path);
    } on FileOperationException catch (error) {
      if (mounted) showMessage(context, error.message, isError: true);
    }
  }

  /// Downloads to a temporary file, then hands it to the system share sheet.
  ///
  /// Streaming to disk rather than into memory is what lets a multi-gigabyte
  /// log be fetched from a phone at all (SPEC 15.4).
  Future<void> _download(RemoteFile file) async {
    final connection = _connection;
    if (connection == null) return;

    final directory = await getTemporaryDirectory();
    final localPath = p.join(directory.path, file.name);

    if (!mounted) return;
    final handle = ref
        .read(sftpServiceProvider)
        .download(connection, remotePath: file.path, localPath: localPath);

    final completed = await showTransferSheet(
      context,
      title: file.name,
      handle: handle,
    );
    if (!completed || !mounted) return;

    await SharePlus.instance.share(
      ShareParams(files: [XFile(localPath)], title: file.name),
    );
  }

  Future<void> _upload() async {
    final connection = _connection;
    final path = _path;
    if (connection == null || path == null) return;

    final picked = await FilePicker.pickFile();
    if (picked == null || !mounted) return;

    // The picker may hand back a SAF URI with no filesystem path; copying to a
    // temp file gives the streaming uploader something it can read.
    var localPath = picked.path;
    String? stagedPath;
    if (localPath == null) {
      final directory = await getTemporaryDirectory();
      localPath = p.join(directory.path, picked.name);
      stagedPath = localPath;
      final sink = File(localPath).openWrite();
      try {
        await for (final chunk in picked.readAsByteStream()) {
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
    }

    if (!mounted) return;
    final handle = ref
        .read(sftpServiceProvider)
        .upload(
          connection,
          localPath: localPath,
          remotePath: SftpService.joinPath(path, picked.name),
        );

    try {
      final completed = await showTransferSheet(
        context,
        title: picked.name,
        handle: handle,
      );
      if (completed && mounted) await _navigate(path);
    } finally {
      if (stagedPath != null) {
        try {
          await File(stagedPath).delete();
        } on FileSystemException {
          // The temporary file may already have been cleaned up by the OS.
        }
      }
    }
  }
}

enum _SortBy { name, size, modified }

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.onTap,
    required this.onLongPress,
  });

  final RemoteFile file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      leading: Icon(
        file.isDirectory
            ? Icons.folder
            : file.isSymlink
            ? Icons.link
            : _iconForExtension(file.extension),
        color: file.isDirectory
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (!file.isDirectory) formatBytes(file.size),
          formatDateTime(file.modified),
          if (file.mode != null) formatPermissions(file.mode),
        ].where((part) => part.isNotEmpty).join('  ·  '),
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
      trailing: file.isDirectory ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  static IconData _iconForExtension(String extension) => switch (extension) {
    'json' || 'yaml' || 'yml' || 'toml' || 'xml' => Icons.data_object_outlined,
    'md' || 'txt' || 'rst' => Icons.article_outlined,
    'log' => Icons.receipt_long_outlined,
    'png' ||
    'jpg' ||
    'jpeg' ||
    'gif' ||
    'webp' ||
    'svg' => Icons.image_outlined,
    'zip' ||
    'tar' ||
    'gz' ||
    'bz2' ||
    'xz' ||
    '7z' => Icons.folder_zip_outlined,
    'dart' ||
    'py' ||
    'js' ||
    'ts' ||
    'go' ||
    'rs' ||
    'java' ||
    'kt' ||
    'c' ||
    'cpp' ||
    'h' ||
    'sh' => Icons.code,
    _ => Icons.insert_drive_file_outlined,
  };
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        autocorrect: false,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (value) {
          if (value.trim().isEmpty) return;
          Navigator.of(context).pop(value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.actionSave),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
