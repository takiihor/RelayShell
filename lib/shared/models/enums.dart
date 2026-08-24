/// Enumerations shared across the whole application.
///
/// Every enum here is persisted by [storageValue] rather than by index so that
/// database rows stay readable and reordering a Dart enum cannot corrupt data.
library;

enum AuthMethod {
  privateKey('private_key'),
  password('password'),
  keyboardInteractive('keyboard_interactive'),
  agent('agent');

  const AuthMethod(this.storageValue);
  final String storageValue;

  static AuthMethod fromStorage(String? value) => AuthMethod.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => AuthMethod.privateKey,
      );
}

enum CredentialType {
  privateKey('private_key'),
  password('password');

  const CredentialType(this.storageValue);
  final String storageValue;

  static CredentialType fromStorage(String? value) =>
      CredentialType.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => CredentialType.privateKey,
      );
}

/// Shell family assumed for a remote machine.
///
/// This drives command quoting (SPEC 29) and the availability of POSIX-only
/// features such as tmux (SPEC 30). Windows is split by shell because cmd.exe
/// and PowerShell quote arguments incompatibly, and getting that wrong is how
/// a path with a space silently becomes two arguments.
enum RemotePlatform {
  posix('posix', 'Linux / macOS / BSD'),
  windowsPowerShell('windows_powershell', 'Windows (PowerShell)'),
  windowsCmd('windows_cmd', 'Windows (cmd.exe)');

  const RemotePlatform(this.storageValue, this.label);
  final String storageValue;
  final String label;

  bool get supportsTmux => this == RemotePlatform.posix;

  bool get isWindows => this != RemotePlatform.posix;

  static RemotePlatform fromStorage(String? value) {
    // 'windows' was the pre-split storage value; PowerShell is the safer
    // reading of it because its quoting rules are well defined.
    if (value == 'windows') return RemotePlatform.windowsPowerShell;
    return RemotePlatform.values.firstWhere(
      (e) => e.storageValue == value,
      orElse: () => RemotePlatform.posix,
    );
  }
}

/// How a terminal session is anchored on the remote machine (SPEC 11.1).
enum SessionMode {
  /// Plain SSH shell. Dies with the connection.
  direct('direct'),

  /// SSH shell attached to a managed tmux session. Survives disconnection.
  persistent('persistent');

  const SessionMode(this.storageValue);
  final String storageValue;

  static SessionMode fromStorage(String? value) =>
      SessionMode.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => SessionMode.direct,
      );
}

enum CommandScope {
  global('global'),
  host('host'),
  project('project');

  const CommandScope(this.storageValue);
  final String storageValue;

  static CommandScope fromStorage(String? value) =>
      CommandScope.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => CommandScope.global,
      );
}

enum ExecutionMode {
  interactive('interactive'),
  oneShot('one_shot');

  const ExecutionMode(this.storageValue);
  final String storageValue;

  static ExecutionMode fromStorage(String? value) =>
      ExecutionMode.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => ExecutionMode.interactive,
      );
}

enum ConfirmationMode {
  none('none'),
  always('always'),
  dangerous('dangerous');

  const ConfirmationMode(this.storageValue);
  final String storageValue;

  static ConfirmationMode fromStorage(String? value) =>
      ConfirmationMode.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => ConfirmationMode.dangerous,
      );
}

enum ForwardType {
  local('local'),
  remote('remote'),
  dynamicSocks('dynamic');

  const ForwardType(this.storageValue);
  final String storageValue;

  static ForwardType fromStorage(String? value) =>
      ForwardType.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => ForwardType.local,
      );
}

/// Advisory host reachability shown on Home (SPEC 7.2). Never blocking.
enum HostReachability { unknown, checking, reachable, unreachable }

/// Connection state machine defined in SPEC 9.1.
enum SshConnectionState {
  idle,
  resolving,
  connecting,
  handshaking,
  verifyingHost,
  authenticating,
  connected,
  reconnecting,
  failed,
  closed;

  bool get isActive =>
      this == SshConnectionState.connected ||
      this == SshConnectionState.reconnecting;

  bool get isTerminal =>
      this == SshConnectionState.failed || this == SshConnectionState.closed;

  /// True while the connection is working toward [connected].
  bool get isBusy => const {
        SshConnectionState.resolving,
        SshConnectionState.connecting,
        SshConnectionState.handshaking,
        SshConnectionState.verifyingHost,
        SshConnectionState.authenticating,
        SshConnectionState.reconnecting,
      }.contains(this);
}

/// Semantic status colours defined by the design system (SPEC 39).
enum SemanticStatus { connected, connecting, warning, error, inactive }

enum AppLockTimeout {
  immediately('immediately', Duration.zero),
  oneMinute('1m', Duration(minutes: 1)),
  fiveMinutes('5m', Duration(minutes: 5)),
  fifteenMinutes('15m', Duration(minutes: 15));

  const AppLockTimeout(this.storageValue, this.duration);
  final String storageValue;
  final Duration duration;

  static AppLockTimeout fromStorage(String? value) =>
      AppLockTimeout.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => AppLockTimeout.immediately,
      );
}

enum ReconnectBehavior {
  ask('ask'),
  autoOnce('auto_once'),
  autoBounded('auto_bounded');

  const ReconnectBehavior(this.storageValue);
  final String storageValue;

  static ReconnectBehavior fromStorage(String? value) =>
      ReconnectBehavior.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => ReconnectBehavior.autoBounded,
      );
}

enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.storageValue);
  final String storageValue;

  static AppThemeMode fromStorage(String? value) =>
      AppThemeMode.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => AppThemeMode.system,
      );
}

enum TerminalCursorStyle {
  block('block'),
  underline('underline'),
  bar('bar');

  const TerminalCursorStyle(this.storageValue);
  final String storageValue;

  static TerminalCursorStyle fromStorage(String? value) =>
      TerminalCursorStyle.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => TerminalCursorStyle.block,
      );
}

enum RecentItemKind {
  host('host'),
  project('project'),
  session('session'),
  command('command');

  const RecentItemKind(this.storageValue);
  final String storageValue;

  static RecentItemKind fromStorage(String? value) =>
      RecentItemKind.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => RecentItemKind.host,
      );
}
