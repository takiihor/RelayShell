import 'multiplexer.dart';
import 'multiplexer_session.dart';
import 'shell_quoting.dart';

/// Builds and parses the tmux commands the app issues (SPEC 11).
///
/// Every generated command goes through [ShellQuoter], and tmux session names
/// are normalised so a project called `My App (v2)` cannot produce a name that
/// tmux rejects or that needs shell escaping in the first place.
class TmuxCommandBuilder {
  const TmuxCommandBuilder({this.quoter = ShellQuoter.posix});

  final ShellQuoter quoter;

  /// Field separator for `list-sessions`. Chosen because tmux session names
  /// cannot contain it, so parsing never has to guess.
  static const String fieldSeparator = '\u001F';

  /// tmux forbids `.` and `:` in session names and treats them as addressing
  /// syntax; everything else is normalised to `-` for predictability.
  static String sanitizeNameComponent(String input) {
    final lowered = input.toLowerCase();
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed;
  }

  /// Generates a predictable managed session name, e.g. `rdc-gobybus-codex`
  /// (SPEC 11.2).
  ///
  /// [existingNames] lets the caller avoid collisions; a numeric suffix is
  /// appended when the preferred name is taken.
  static String managedSessionName({
    required String prefix,
    required String subject,
    String? action,
    Set<String> existingNames = const {},
  }) {
    final parts = <String>[
      sanitizeNameComponent(prefix),
      sanitizeNameComponent(subject),
      if (action != null && action.trim().isNotEmpty)
        sanitizeNameComponent(action),
    ].where((p) => p.isNotEmpty).toList();

    final base = parts.isEmpty ? 'session' : parts.join('-');
    if (!existingNames.contains(base)) return base;

    for (var i = 2; i < 1000; i++) {
      final candidate = '$base-$i';
      if (!existingNames.contains(candidate)) return candidate;
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Command that lists sessions in a machine-readable form, or exits non-zero
  /// when tmux is missing.
  String listSessions() {
    const format =
        '#{session_name}\u001F#{session_windows}\u001F#{session_attached}'
        '\u001F#{session_created}';
    return 'command -v tmux >/dev/null 2>&1 || exit 127; '
        'tmux list-sessions -F ${quoter.quote(format)} 2>/dev/null || true';
  }

  /// Command that reports whether tmux exists, printing its version.
  String detect() =>
      'command -v tmux >/dev/null 2>&1 && tmux -V || '
      'echo ${Multiplexer.missingSentinel}';

  /// Server options applied before attaching, as a `;`-separated prelude.
  ///
  /// `mouse on` is what makes the terminal scrollable from a phone. Without it
  /// tmux leaves the emulator in the alternate screen buffer with no mouse
  /// reporting, and a touch drag produces nothing at all: the alternate buffer
  /// has no scrollback of its own, and tmux never sees the gesture. With it,
  /// the drag arrives as wheel events and tmux scrolls its own history.
  ///
  /// `history-limit` is raised because tmux's 2000-line default, not the app's
  /// scrollback preference, is what actually bounds a persistent session.
  ///
  /// Set with `-g` on the server, and tolerant of failure (`|| true`) so an
  /// unusual tmux build cannot stop the user attaching to their work.
  static const String sessionSetup =
      'tmux set -g mouse on >/dev/null 2>&1 || true; '
      'tmux set -g history-limit 50000 >/dev/null 2>&1 || true; ';

  /// Attaches to [name], creating it in [workingDirectory] if absent.
  ///
  /// `new-session -A` is a single atomic "attach or create", which avoids the
  /// race where two phones both see "no session" and each create one.
  String attachOrCreate(String name, {String? workingDirectory}) {
    final buffer = StringBuffer(sessionSetup);
    buffer.write('tmux new-session -A -s ${quoter.quote(name)}');
    if (workingDirectory != null && workingDirectory.isNotEmpty) {
      buffer.write(' -c ${quoter.quote(workingDirectory)}');
    }
    return buffer.toString();
  }

  /// Attaches to [name] and immediately runs [command] inside it.
  ///
  /// The command is passed as tmux's shell-command argument, so it is quoted
  /// once for the outer shell; tmux hands it to the remote shell intact.
  String attachOrCreateRunning(
    String name,
    String command, {
    String? workingDirectory,
  }) {
    final buffer = StringBuffer(sessionSetup);
    buffer.write('tmux new-session -A -s ${quoter.quote(name)}');
    if (workingDirectory != null && workingDirectory.isNotEmpty) {
      buffer.write(' -c ${quoter.quote(workingDirectory)}');
    }
    buffer.write(' ${quoter.quote(command)}');
    return buffer.toString();
  }

  String killSession(String name) =>
      'tmux kill-session -t ${quoter.quote(name)}';

  String renameSession(String from, String to) =>
      'tmux rename-session -t ${quoter.quote(from)} ${quoter.quote(to)}';

  String hasSession(String name) =>
      'tmux has-session -t ${quoter.quote(name)} 2>/dev/null';

  String detachOthers(String name) =>
      'tmux attach-session -d -t ${quoter.quote(name)}';

  /// Parses the output of [listSessions].
  ///
  /// Unparseable lines are skipped rather than throwing: a single odd line from
  /// an unusual tmux build should not hide every other session.
  List<MultiplexerSession> parseSessions(String output) {
    final sessions = <MultiplexerSession>[];
    for (final rawLine in output.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final fields = line.split(fieldSeparator);
      if (fields.length < 3) continue;
      final name = fields[0].trim();
      if (name.isEmpty) continue;
      final createdEpoch = fields.length > 3
          ? int.tryParse(fields[3].trim())
          : null;
      sessions.add(
        MultiplexerSession(
          name: name,
          windows: int.tryParse(fields[1].trim()) ?? 1,
          attached: (int.tryParse(fields[2].trim()) ?? 0) > 0,
          created: createdEpoch == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(createdEpoch * 1000),
        ),
      );
    }
    return sessions;
  }
}
