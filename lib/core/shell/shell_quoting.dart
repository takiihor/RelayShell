import '../../shared/models/enums.dart';

/// Thrown when a value cannot be represented safely in a target shell.
///
/// Raising instead of emitting a best-effort string is deliberate: a silently
/// mis-quoted argument is a command injection, not a cosmetic bug.
class UnquotableArgumentError implements Exception {
  UnquotableArgumentError(this.value, this.reason);

  final String value;
  final String reason;

  @override
  String toString() => 'UnquotableArgumentError: $reason';
}

/// Quotes a single argument for a remote shell (SPEC 29).
///
/// The app never interpolates a path or name into a generated command without
/// going through a quoter. User-authored saved commands are exempt: they are
/// intentional shell input and are sent verbatim.
abstract class ShellQuoter {
  const ShellQuoter();

  /// Returns [value] safe to paste as one argument in this shell.
  String quote(String value);

  /// Builds a change-directory command for this shell.
  String changeDirectory(String path);

  /// Sequences commands so the second runs only if the first succeeded.
  String andThen(String first, String second);

  /// Rejects values no quoting scheme can carry through a command line.
  void rejectUnquotable(String value) {
    if (value.contains('\u0000')) {
      throw UnquotableArgumentError(value, 'Value contains a NUL byte.');
    }
    if (value.contains('\n') || value.contains('\r')) {
      throw UnquotableArgumentError(
        value,
        'Value contains a line break, which would split the command.',
      );
    }
  }

  static const ShellQuoter posix = PosixShellQuoter();
  static const ShellQuoter powerShell = PowerShellQuoter();
  static const ShellQuoter cmd = WindowsCmdQuoter();

  static ShellQuoter forPlatform(RemotePlatform platform) => switch (platform) {
        RemotePlatform.posix => posix,
        RemotePlatform.windowsPowerShell => powerShell,
        RemotePlatform.windowsCmd => cmd,
      };
}

/// POSIX `sh`/`bash`/`zsh` quoting.
///
/// Single quotes disable every expansion, so the only special case is an
/// embedded single quote: close the string, emit an escaped quote, reopen.
class PosixShellQuoter extends ShellQuoter {
  const PosixShellQuoter();

  /// Characters that never need quoting in any POSIX shell.
  static final RegExp _bare = RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$');

  @override
  String quote(String value) {
    rejectUnquotable(value);
    if (value.isEmpty) return "''";
    if (_bare.hasMatch(value)) return value;
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  @override
  String changeDirectory(String path) => 'cd ${quote(path)}';

  @override
  String andThen(String first, String second) => '$first && $second';
}

/// PowerShell quoting.
///
/// Inside single quotes PowerShell performs no expansion at all; a literal
/// single quote is written by doubling it.
class PowerShellQuoter extends ShellQuoter {
  const PowerShellQuoter();

  @override
  String quote(String value) {
    rejectUnquotable(value);
    if (value.isEmpty) return "''";
    return "'${value.replaceAll("'", "''")}'";
  }

  @override
  String changeDirectory(String path) =>
      'Set-Location -LiteralPath ${quote(path)}';

  @override
  String andThen(String first, String second) =>
      '$first; if (\$?) { $second }';
}

/// cmd.exe quoting.
///
/// cmd.exe's two-pass parser has no escape that reliably survives for `%` and
/// `!`, so values containing them are rejected rather than mangled.
class WindowsCmdQuoter extends ShellQuoter {
  const WindowsCmdQuoter();

  @override
  String quote(String value) {
    rejectUnquotable(value);
    if (value.isEmpty) return '""';
    if (value.contains('%') || value.contains('!')) {
      throw UnquotableArgumentError(
        value,
        'cmd.exe cannot safely quote "%" or "!". '
        'Set this computer to PowerShell, or rename the path.',
      );
    }
    if (value.contains('"')) {
      throw UnquotableArgumentError(
        value,
        'cmd.exe cannot safely quote a double-quote character.',
      );
    }
    return '"$value"';
  }

  @override
  String changeDirectory(String path) => 'cd /d ${quote(path)}';

  @override
  String andThen(String first, String second) => '$first && $second';
}
