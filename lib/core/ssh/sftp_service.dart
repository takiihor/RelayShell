import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'ssh_connection.dart';
import 'ssh_failure.dart';

/// One entry in a remote directory listing (SPEC 15.1).
@immutable
class RemoteFile {
  const RemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isSymlink,
    this.size,
    this.modified,
    this.mode,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymlink;
  final int? size;
  final DateTime? modified;

  /// POSIX permission bits, when the server reported them.
  final int? mode;

  bool get isHidden => name.startsWith('.');

  /// Extension in lower case, without the dot.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Progress of a running transfer (SPEC 15.4).
@immutable
class TransferProgress {
  const TransferProgress({
    required this.transferred,
    required this.total,
    required this.done,
  });

  final int transferred;

  /// Null when the size is not known in advance.
  final int? total;
  final bool done;

  double? get fraction {
    final total = this.total;
    if (total == null || total <= 0) return null;
    return (transferred / total).clamp(0.0, 1.0);
  }
}

/// A transfer the caller can watch and cancel.
class TransferHandle {
  TransferHandle._(this._progress, this._cancel, this.completion);

  final Stream<TransferProgress> _progress;
  final void Function() _cancel;

  /// Completes when the transfer finishes, or with an error if it failed.
  final Future<void> completion;

  Stream<TransferProgress> get progress => _progress;

  /// Stops the transfer. The partial destination file is left for the caller
  /// to clean up, so a resumable download is still possible later.
  void cancel() => _cancel();
}

/// Raised when a file operation fails, with a message worth showing.
class FileOperationException implements Exception {
  const FileOperationException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => message;
}

/// Remote file operations over SFTP (SPEC 15).
///
/// Transfers stream in both directions and never hold a whole file in memory
/// (SPEC 15.4, 36); only the small-file viewer reads a bounded amount into a
/// string, and it enforces that bound itself.
class SftpService {
  const SftpService();

  /// Largest file the built-in viewer will open (SPEC 15.3).
  ///
  /// Chosen so a log tail or source file always opens, while a database dump
  /// cannot exhaust a phone's memory.
  static const int maxViewableBytes = 1024 * 1024;

  Future<SftpClient> _client(SshConnection connection) => connection.sftp();

  /// Resolves a path to its absolute form; `.` yields the login directory.
  Future<String> resolve(SshConnection connection, String path) async {
    final sftp = await _client(connection);
    try {
      return await sftp.absolute(path.isEmpty ? '.' : path);
    } catch (error) {
      throw _wrap(error, 'Could not resolve "$path".');
    }
  }

  /// The user's home directory on the remote machine.
  Future<String> homeDirectory(SshConnection connection) =>
      resolve(connection, '.');

  /// Lists [path], sorted directories-first then by name.
  ///
  /// `.` and `..` are dropped: navigation up is a UI affordance, not a row in
  /// the list that can be renamed or deleted by accident.
  Future<List<RemoteFile>> list(SshConnection connection, String path) async {
    final sftp = await _client(connection);
    final List<SftpName> names;
    try {
      names = await sftp.listdir(path);
    } catch (error) {
      throw _wrap(error, 'Could not open "$path".');
    }

    final files = <RemoteFile>[];
    for (final entry in names) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      files.add(_toRemoteFile(entry, parentPath: path));
    }

    files.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return files;
  }

  Future<RemoteFile> stat(SshConnection connection, String path) async {
    final sftp = await _client(connection);
    try {
      final attrs = await sftp.stat(path);
      return RemoteFile(
        name: _basename(path),
        path: path,
        isDirectory: attrs.isDirectory,
        isSymlink: attrs.isSymbolicLink,
        size: attrs.size,
        modified: _toDateTime(attrs.modifyTime),
        mode: attrs.mode?.value,
      );
    } catch (error) {
      throw _wrap(error, 'Could not read "$path".');
    }
  }

  Future<void> createDirectory(SshConnection connection, String path) async {
    final sftp = await _client(connection);
    try {
      await sftp.mkdir(path);
    } catch (error) {
      throw _wrap(error, 'Could not create the folder.');
    }
  }

  Future<void> rename(SshConnection connection, String from, String to) async {
    final sftp = await _client(connection);
    try {
      await sftp.rename(from, to);
    } catch (error) {
      throw _wrap(error, 'Could not rename "${_basename(from)}".');
    }
  }

  Future<void> deleteFile(SshConnection connection, String path) async {
    final sftp = await _client(connection);
    try {
      await sftp.remove(path);
    } catch (error) {
      throw _wrap(error, 'Could not delete "${_basename(path)}".');
    }
  }

  /// Removes an empty directory.
  Future<void> deleteDirectory(SshConnection connection, String path) async {
    final sftp = await _client(connection);
    try {
      await sftp.rmdir(path);
    } catch (error) {
      throw _wrap(
        error,
        'Could not delete "${_basename(path)}". It may not be empty.',
      );
    }
  }

  /// Recursively deletes a directory tree.
  ///
  /// Walked client-side rather than by running `rm -rf` remotely: the file
  /// browser must work on hosts where the SSH server allows SFTP but not shell
  /// execution, and an explicit walk cannot be turned into a wildcard that
  /// deletes more than the user pointed at (SPEC 15.2).
  Future<int> deleteRecursively(
    SshConnection connection,
    String path, {
    void Function(String currentPath)? onProgress,
  }) async {
    var removed = 0;
    final entries = await list(connection, path);
    for (final entry in entries) {
      onProgress?.call(entry.path);
      if (entry.isDirectory && !entry.isSymlink) {
        removed += await deleteRecursively(
          connection,
          entry.path,
          onProgress: onProgress,
        );
      } else {
        await deleteFile(connection, entry.path);
        removed++;
      }
    }
    await deleteDirectory(connection, path);
    return removed + 1;
  }

  /// Counts entries under [path], so a delete confirmation can say how much is
  /// about to disappear.
  Future<int> countEntries(
    SshConnection connection,
    String path, {
    int limit = 500,
  }) async {
    var count = 0;
    Future<void> walk(String current) async {
      if (count >= limit) return;
      final entries = await list(connection, current);
      for (final entry in entries) {
        if (count >= limit) return;
        count++;
        if (entry.isDirectory && !entry.isSymlink) await walk(entry.path);
      }
    }

    await walk(path);
    return count;
  }

  /// Reads a small text file for the built-in viewer (SPEC 15.3).
  ///
  /// Refuses anything over [maxViewableBytes] rather than truncating silently,
  /// so the UI can offer to download instead of showing half a file that looks
  /// complete.
  Future<String> readTextFile(
    SshConnection connection,
    String path, {
    int maxBytes = maxViewableBytes,
  }) async {
    final info = await stat(connection, path);
    final size = info.size;
    if (size != null && size > maxBytes) {
      throw FileOperationException(
        'This file is too large to open here '
        '(${_formatBytes(size)}). Download it instead.',
      );
    }

    final sftp = await _client(connection);
    final file = await sftp.open(path);
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.read()) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw FileOperationException(
            'This file is too large to open here. Download it instead.',
          );
        }
      }
      return const Utf8Decoder(allowMalformed: true)
          .convert(builder.takeBytes());
    } finally {
      await file.close();
    }
  }

  /// Overwrites a small text file (SPEC 15.3).
  Future<void> writeTextFile(
    SshConnection connection,
    String path,
    String contents,
  ) async {
    final sftp = await _client(connection);
    final file = await sftp.open(
      path,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(Uint8List.fromList(utf8.encode(contents)));
    } catch (error) {
      throw _wrap(error, 'Could not save "${_basename(path)}".');
    } finally {
      await file.close();
    }
  }

  /// Downloads [remotePath] to [localPath], streaming with progress.
  TransferHandle download(
    SshConnection connection, {
    required String remotePath,
    required String localPath,
  }) {
    final progress = StreamController<TransferProgress>.broadcast();
    final completer = Completer<void>();
    var cancelled = false;

    Future<void> run() async {
      IOSink? sink;
      SftpFile? file;
      try {
        final info = await stat(connection, remotePath);
        final total = info.size;

        final sftp = await _client(connection);
        file = await sftp.open(remotePath);
        sink = File(localPath).openWrite();

        var transferred = 0;
        progress.add(
          TransferProgress(transferred: 0, total: total, done: false),
        );

        await for (final chunk in file.read()) {
          if (cancelled) break;
          sink.add(chunk);
          transferred += chunk.length;
          progress.add(
            TransferProgress(
              transferred: transferred,
              total: total,
              done: false,
            ),
          );
        }

        await sink.flush();
        await sink.close();
        sink = null;

        if (cancelled) {
          completer.completeError(
            const FileOperationException('Download cancelled.'),
          );
        } else {
          progress.add(
            TransferProgress(
              transferred: transferred,
              total: total,
              done: true,
            ),
          );
          completer.complete();
        }
      } catch (error) {
        completer.completeError(
          _wrap(error, 'Could not download "${_basename(remotePath)}".'),
        );
      } finally {
        await file?.close();
        await sink?.close();
        await progress.close();
      }
    }

    unawaited(run());
    return TransferHandle._(
      progress.stream,
      () => cancelled = true,
      completer.future,
    );
  }

  /// Uploads [localPath] to [remotePath], streaming with progress.
  TransferHandle upload(
    SshConnection connection, {
    required String localPath,
    required String remotePath,
  }) {
    final progress = StreamController<TransferProgress>.broadcast();
    final completer = Completer<void>();
    var cancelled = false;

    Future<void> run() async {
      SftpFile? file;
      try {
        final source = File(localPath);
        final total = await source.length();

        final sftp = await _client(connection);
        file = await sftp.open(
          remotePath,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );

        var transferred = 0;
        progress.add(
          TransferProgress(transferred: 0, total: total, done: false),
        );

        // Chunks are written at an explicit offset rather than appended, so a
        // short write cannot silently interleave.
        await for (final chunk in source.openRead()) {
          if (cancelled) break;
          final bytes = Uint8List.fromList(chunk);
          await file.writeBytes(bytes, offset: transferred);
          transferred += bytes.length;
          progress.add(
            TransferProgress(
              transferred: transferred,
              total: total,
              done: false,
            ),
          );
        }

        if (cancelled) {
          completer.completeError(
            const FileOperationException('Upload cancelled.'),
          );
        } else {
          progress.add(
            TransferProgress(
              transferred: transferred,
              total: total,
              done: true,
            ),
          );
          completer.complete();
        }
      } catch (error) {
        completer.completeError(
          _wrap(error, 'Could not upload "${_basename(localPath)}".'),
        );
      } finally {
        await file?.close();
        await progress.close();
      }
    }

    unawaited(run());
    return TransferHandle._(
      progress.stream,
      () => cancelled = true,
      completer.future,
    );
  }

  static RemoteFile _toRemoteFile(
    SftpName entry, {
    required String parentPath,
  }) {
    final attrs = entry.attr;
    return RemoteFile(
      name: entry.filename,
      path: joinPath(parentPath, entry.filename),
      isDirectory: attrs.isDirectory,
      isSymlink: attrs.isSymbolicLink,
      size: attrs.size,
      modified: _toDateTime(attrs.modifyTime),
      mode: attrs.mode?.value,
    );
  }

  static DateTime? _toDateTime(int? epochSeconds) => epochSeconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);

  /// Joins remote path segments. Remote paths are POSIX even when the client
  /// runs on a platform with a different separator.
  static String joinPath(String parent, String child) {
    if (parent.isEmpty || parent == '.') return child;
    if (parent.endsWith('/')) return '$parent$child';
    return '$parent/$child';
  }

  /// The parent of a remote path, or null at the root.
  static String? parentOf(String path) {
    if (path == '/' || path.isEmpty) return null;
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    if (slash < 0) return null;
    if (slash == 0) return '/';
    return trimmed.substring(0, slash);
  }

  static String _basename(String path) {
    final slash = path.lastIndexOf('/');
    if (slash < 0 || slash == path.length - 1) return path;
    return path.substring(slash + 1);
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final rounded = unit == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$rounded ${units[unit]}';
  }

  static Object _wrap(Object error, String message) {
    if (error is FileOperationException) return error;
    if (error is SshFailure) return error;
    if (error is SftpStatusError) {
      return FileOperationException(message, detail: error.message);
    }
    return FileOperationException(message, detail: error.toString());
  }
}
