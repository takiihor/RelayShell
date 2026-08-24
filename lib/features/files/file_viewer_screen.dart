import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ssh/sftp_service.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';

/// Read-only viewer with light editing for small files (SPEC 15.3).
///
/// Deliberately not an IDE: no syntax highlighting, no multi-file state, no
/// autosave. It exists so a config typo or a one-line fix does not require
/// finding a laptop.
class FileViewerScreen extends ConsumerStatefulWidget {
  const FileViewerScreen({
    required this.connection,
    required this.file,
    super.key,
  });

  final SshConnection connection;
  final RemoteFile file;

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  final TextEditingController _controller = TextEditingController();

  String _original = '';
  Object? _error;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  bool get _isDirty => _editing && _controller.text != _original;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final text = await ref.read(sftpServiceProvider).readTextFile(
            widget.connection,
            widget.file.path,
          );
      if (!mounted) return;
      setState(() {
        _original = text;
        _controller.text = text;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);

    try {
      await ref.read(sftpServiceProvider).writeTextFile(
            widget.connection,
            widget.file.path,
            _controller.text,
          );
      if (!mounted) return;
      setState(() {
        _original = _controller.text;
        _editing = false;
        _saving = false;
      });
      showMessage(context, l10n.filesSaved);
    } on FileOperationException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, error.message, isError: true);
    }
  }

  Future<void> _toggleEditing() async {
    if (_editing && !await _confirmDiscard()) return;
    if (!mounted) return;
    setState(() {
      if (_editing) _controller.text = _original;
      _editing = !_editing;
    });
  }

  /// Confirms before dropping unsaved edits when the user navigates back.
  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    // State.context, guarded by State.mounted, so the check and the use refer
    // to the same lifecycle.
    Navigator.of(context).pop();
  }

  /// Guards against losing edits on back-navigation.
  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context);
    return confirmDestructive(
      context,
      title: l10n.filesUnsavedTitle,
      body: l10n.filesUnsavedBody,
      confirmLabel: l10n.actionClose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.file.name, overflow: TextOverflow.ellipsis),
              Text(
                [
                  formatBytes(widget.file.size),
                  if (!_editing) l10n.filesReadOnlyNote,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            if (!_loading && _error == null)
              IconButton(
                icon: Icon(_editing ? Icons.visibility : Icons.edit_outlined),
                tooltip: _editing ? l10n.filesReadOnlyNote : l10n.actionEdit,
                onPressed: _toggleEditing,
              ),
            if (_editing)
              TextButton(
                onPressed: _saving || !_isDirty ? null : _save,
                child: Text(l10n.filesSaveChanges),
              ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_loading) return const LoadingView();

    final error = _error;
    if (error != null) {
      return EmptyState(
        icon: Icons.description_outlined,
        title: l10n.filesLoadFailed,
        body: error is FileOperationException
            ? error.message
            : error.toString(),
        actionLabel: l10n.actionRetry,
        onAction: _load,
      );
    }

    if (!_editing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          _controller.text.isEmpty ? l10n.filesEmptyFolder : _controller.text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.secondaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.filesEditNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              autocorrect: false,
              enableSuggestions: false,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
              ),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
      ],
    );
  }
}
