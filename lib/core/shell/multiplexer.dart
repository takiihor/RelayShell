import '../../shared/models/enums.dart';
import 'multiplexer_session.dart';
import 'shell_quoting.dart';
import 'tmux.dart';

/// Builds the remote command lines for one terminal-multiplexer backend.
///
/// The app supports more than one because the choice is the user's workflow,
/// not an implementation detail: tmux is everywhere, Herdr is built for driving
/// coding agents and — unlike a default tmux — captures the mouse, which is the
/// difference between a scrollable phone terminal and a dead one.
///
/// Every generated argument goes through [quoter]. Session names are sanitised
/// first so they cannot produce something the backend rejects or that would
/// need escaping in the first place.
abstract class Multiplexer {
  const Multiplexer({required this.quoter});

  final ShellQuoter quoter;

  MultiplexerKind get kind;

  /// The executable the remote machine must have.
  String get executable;

  /// Bytes that detach the client, leaving remote work running.
  ///
  /// Sent as keystrokes rather than closing the channel so the backend tears
  /// its client down in its own time.
  String get detachSequence;

  /// Whether this backend can rename a live session.
  bool get supportsRename => false;

  /// Whether a command can be handed to the backend at create time.
  ///
  /// When false, the caller runs the command by typing it into the attached
  /// session instead — see [SessionLaunchPlan.initialInput].
  bool get supportsStartupCommand => false;

  /// Command that prints a version, or a sentinel when the tool is missing.
  String detect();

  /// Sentinel [detect] prints when the executable is absent.
  static const String missingSentinel = '__NO_MUX__';

  /// Command that lists sessions machine-readably, exiting 127 when missing.
  String listSessions();

  /// Parses the output of [listSessions].
  List<MultiplexerSession> parseSessions(String output);

  /// Single atomic "attach if it exists, otherwise create".
  String attachOrCreate(String name, {String? workingDirectory});

  /// Attaches to (or creates) [name] and runs [command] inside it.
  ///
  /// Only valid when [supportsStartupCommand] is true.
  String attachOrCreateRunning(
    String name,
    String command, {
    String? workingDirectory,
  }) => throw UnsupportedError(
    '${kind.label} cannot run a command at create time.',
  );

  String killSession(String name);

  String hasSession(String name);

  /// Renames a live session. Throws when [supportsRename] is false.
  String renameSession(String from, String to) =>
      throw UnsupportedError('${kind.label} cannot rename a live session.');

  /// Generates a collision-free managed session name, e.g. `rdc-gobybus-codex`.
  String managedSessionName({
    required String prefix,
    required String subject,
    String? action,
    Set<String> existingNames = const {},
  }) => TmuxCommandBuilder.managedSessionName(
    prefix: prefix,
    subject: subject,
    action: action,
    existingNames: existingNames,
  );

  static Multiplexer of(MultiplexerKind kind, {required ShellQuoter quoter}) =>
      switch (kind) {
        MultiplexerKind.tmux => TmuxMultiplexer(quoter: quoter),
        MultiplexerKind.herdr => HerdrMultiplexer(quoter: quoter),
      };

  static Multiplexer forPlatform(
    MultiplexerKind kind,
    RemotePlatform platform,
  ) => of(kind, quoter: ShellQuoter.forPlatform(platform));
}

/// tmux backend.
///
/// Delegates command construction to [TmuxCommandBuilder], which predates this
/// abstraction and is still the authority on tmux syntax.
class TmuxMultiplexer extends Multiplexer {
  const TmuxMultiplexer({super.quoter = ShellQuoter.posix});

  TmuxCommandBuilder get _builder => TmuxCommandBuilder(quoter: quoter);

  @override
  MultiplexerKind get kind => MultiplexerKind.tmux;

  @override
  String get executable => 'tmux';

  /// `prefix + d`, the default tmux detach binding.
  @override
  String get detachSequence => '\x02d';

  @override
  bool get supportsRename => true;

  @override
  bool get supportsStartupCommand => true;

  @override
  String detect() => _builder.detect();

  @override
  String listSessions() => _builder.listSessions();

  @override
  List<MultiplexerSession> parseSessions(String output) =>
      _builder.parseSessions(output);

  @override
  String attachOrCreate(String name, {String? workingDirectory}) =>
      _builder.attachOrCreate(name, workingDirectory: workingDirectory);

  @override
  String attachOrCreateRunning(
    String name,
    String command, {
    String? workingDirectory,
  }) => _builder.attachOrCreateRunning(
    name,
    command,
    workingDirectory: workingDirectory,
  );

  @override
  String killSession(String name) => _builder.killSession(name);

  @override
  String hasSession(String name) => _builder.hasSession(name);

  @override
  String renameSession(String from, String to) =>
      _builder.renameSession(from, to);
}

/// Herdr backend — a terminal workspace manager aimed at coding agents.
///
/// Two differences from tmux drive the code here. Herdr captures the mouse by
/// default, so a phone's touch drag arrives as wheel events it scrolls with;
/// and it has no rename, so [supportsRename] stays false rather than emitting a
/// command that would fail on the far side.
class HerdrMultiplexer extends Multiplexer {
  const HerdrMultiplexer({super.quoter = ShellQuoter.posix});

  @override
  MultiplexerKind get kind => MultiplexerKind.herdr;

  @override
  String get executable => 'herdr';

  /// `prefix + q`, the default Herdr detach binding.
  @override
  String get detachSequence => '\x02q';

  // Every Herdr command goes through a login shell. The usual install puts the
  // binary in ~/.local/bin, which an SSH exec channel does not have on PATH, so
  // without this Herdr is "command not found" on a machine where it is plainly
  // installed and running.

  @override
  String detect() => quoter.loginShell(
    'command -v herdr >/dev/null 2>&1 && herdr --version || '
    'echo ${Multiplexer.missingSentinel}',
  );

  /// Herdr reports sessions as JSON on stdout.
  ///
  /// `|| true` keeps a machine with Herdr installed but no server running from
  /// looking like a machine without Herdr; only a missing binary exits 127.
  @override
  String listSessions() => quoter.loginShell(
    'command -v herdr >/dev/null 2>&1 || exit 127; '
    'herdr session list --json 2>/dev/null || true',
  );

  /// Parses `herdr session list --json`.
  ///
  /// Hand-parsed rather than via `dart:convert` so a malformed or truncated
  /// response degrades to "no sessions" instead of throwing into the UI; the
  /// shape is flat and fully known.
  @override
  List<MultiplexerSession> parseSessions(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) return const [];

    final sessions = <MultiplexerSession>[];
    // Each element looks like {"default":true,"name":"x","running":true,...}.
    for (final match in RegExp(r'\{[^{}]*\}').allMatches(trimmed)) {
      final object = match.group(0)!;
      final name = _stringField(object, 'name');
      if (name == null || name.isEmpty) continue;
      sessions.add(
        MultiplexerSession(
          name: name,
          // Herdr does not report a window count in the session list.
          windows: 0,
          attached: _boolField(object, 'running') ?? false,
          directory: _stringField(object, 'session_dir'),
        ),
      );
    }
    return sessions;
  }

  static String? _stringField(String object, String key) {
    final match = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(
      object,
    );
    return match?.group(1)?.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
  }

  static bool? _boolField(String object, String key) {
    final match = RegExp('"$key"\\s*:\\s*(true|false)').firstMatch(object);
    return match == null ? null : match.group(1) == 'true';
  }

  /// `herdr --session NAME` launches or attaches in one step, like
  /// `tmux new-session -A`.
  ///
  /// Herdr has no `-c` equivalent, so the working directory is applied by the
  /// surrounding shell before Herdr starts. It is `cd ... &&`, not `cd ...;`,
  /// so a bad path fails loudly instead of silently starting somewhere else.
  @override
  String attachOrCreate(String name, {String? workingDirectory}) {
    final attach = 'herdr --session ${quoter.quote(name)}';
    if (workingDirectory == null || workingDirectory.isEmpty) {
      return quoter.loginShell(attach);
    }
    return quoter.loginShell(
      quoter.andThen(quoter.changeDirectory(workingDirectory), attach),
    );
  }

  // `herdr --session` takes no startup command, so [supportsStartupCommand]
  // stays false and the caller types the command into the attached pane.

  @override
  String killSession(String name) =>
      quoter.loginShell('herdr session stop ${quoter.quote(name)}');

  @override
  String hasSession(String name) => quoter.loginShell(
    'herdr session list --json 2>/dev/null | '
    'grep -q ${quoter.quote('"name":"$name"')}',
  );
}
