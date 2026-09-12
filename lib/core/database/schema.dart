/// Local SQLite schema (SPEC 23).
///
/// Migrations are expressed as an ordered list of steps rather than a single
/// `onUpgrade` switch, so tests can replay every upgrade path from any prior
/// version (SPEC 43).
library;

/// Current schema version. Increment when adding a [schemaMigrations] entry.
const int schemaVersion = 3;

/// One forward migration step.
class SchemaMigration {
  const SchemaMigration({required this.version, required this.statements});

  /// The version this migration produces.
  final int version;

  /// Statements executed in order, inside a transaction.
  final List<String> statements;
}

/// Statements that create the version 1 schema from empty.
///
/// Deliberately frozen at version 1: [AppDatabase] replays every migration over
/// a fresh database too, so a new install and an upgraded one are provably the
/// same shape. Adding a column here as well would apply it twice.
///
/// `credentials` intentionally has no column for secret material: private
/// keys, passwords and passphrases live only in platform secure storage and are
/// referenced by id (SPEC 23.2, 44.1).
const List<String> createSchemaStatements = [
  '''
  CREATE TABLE credentials (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    public_key TEXT,
    key_type TEXT,
    fingerprint_sha256 TEXT,
    has_passphrase INTEGER NOT NULL DEFAULT 0,
    require_biometric INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE hosts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    hostname TEXT NOT NULL,
    port INTEGER NOT NULL DEFAULT 22,
    username TEXT NOT NULL,
    auth_method TEXT NOT NULL,
    credential_id TEXT REFERENCES credentials(id) ON DELETE SET NULL,
    startup_directory TEXT,
    environment_notes TEXT,
    color_value INTEGER,
    platform TEXT NOT NULL DEFAULT 'posix',
    favorite INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    last_connected_at INTEGER
  )
  ''',
  'CREATE INDEX idx_hosts_favorite ON hosts(favorite, last_connected_at)',
  '''
  CREATE TABLE trusted_host_keys (
    id TEXT PRIMARY KEY,
    host_id TEXT REFERENCES hosts(id) ON DELETE SET NULL,
    hostname TEXT NOT NULL,
    port INTEGER NOT NULL,
    key_type TEXT NOT NULL,
    fingerprint_sha256 TEXT NOT NULL,
    trusted_at INTEGER NOT NULL,
    UNIQUE (hostname, port, key_type)
  )
  ''',
  '''
  CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    host_id TEXT NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    remote_path TEXT NOT NULL,
    description TEXT,
    default_session_mode TEXT NOT NULL DEFAULT 'direct',
    default_tmux_name TEXT,
    favorite INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    last_opened_at INTEGER
  )
  ''',
  'CREATE INDEX idx_projects_host ON projects(host_id)',
  '''
  CREATE TABLE commands (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    command TEXT NOT NULL,
    scope TEXT NOT NULL,
    host_id TEXT REFERENCES hosts(id) ON DELETE CASCADE,
    project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
    working_directory TEXT,
    execution_mode TEXT NOT NULL DEFAULT 'one_shot',
    confirmation_mode TEXT NOT NULL DEFAULT 'dangerous',
    session_mode TEXT NOT NULL DEFAULT 'direct',
    favorite INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_commands_scope ON commands(scope, host_id, project_id)',
  '''
  CREATE TABLE terminal_profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    theme_id TEXT NOT NULL,
    font_family TEXT NOT NULL,
    font_size REAL NOT NULL,
    cursor_style TEXT NOT NULL,
    scrollback_lines INTEGER NOT NULL,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE session_records (
    id TEXT PRIMARY KEY,
    host_id TEXT NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
    tmux_session_name TEXT,
    display_name TEXT NOT NULL,
    mode TEXT NOT NULL,
    working_directory TEXT,
    launch_command_id TEXT REFERENCES commands(id) ON DELETE SET NULL,
    launch_command TEXT,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_sessions_recent ON session_records(last_used_at DESC)',
  '''
  CREATE UNIQUE INDEX idx_sessions_tmux
    ON session_records(host_id, tmux_session_name)
    WHERE tmux_session_name IS NOT NULL
  ''',
  '''
  CREATE TABLE port_forward_profiles (
    id TEXT PRIMARY KEY,
    host_id TEXT NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    listen_port INTEGER NOT NULL,
    listen_address TEXT NOT NULL DEFAULT '127.0.0.1',
    target_host TEXT,
    target_port INTEGER,
    auto_start INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_forwards_host ON port_forward_profiles(host_id)',
  '''
  CREATE TABLE wol_profiles (
    host_id TEXT PRIMARY KEY REFERENCES hosts(id) ON DELETE CASCADE,
    mac_address TEXT NOT NULL,
    broadcast_address TEXT NOT NULL DEFAULT '255.255.255.255',
    port INTEGER NOT NULL DEFAULT 9
  )
  ''',
  '''
  CREATE TABLE app_preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE recent_items (
    kind TEXT NOT NULL,
    target_id TEXT NOT NULL,
    last_used_at INTEGER NOT NULL,
    PRIMARY KEY (kind, target_id)
  )
  ''',
  'CREATE INDEX idx_recents ON recent_items(last_used_at DESC)',
];

/// Forward migrations beyond version 1.
///
/// Every schema change appends one entry here and bumps [schemaVersion].
const List<SchemaMigration> schemaMigrations = [
  // v2: hosts choose their persistent-session backend. Existing rows default to
  // tmux, which is what they were using before the column existed.
  SchemaMigration(
    version: 2,
    statements: [
      "ALTER TABLE hosts ADD COLUMN multiplexer TEXT NOT NULL DEFAULT 'tmux'",
    ],
  ),
  SchemaMigration(
    version: 3,
    statements: [
      'ALTER TABLE session_records ADD COLUMN herdr_terminal_id TEXT',
      'DROP INDEX idx_sessions_tmux',
      '''CREATE UNIQUE INDEX idx_sessions_tmux
         ON session_records(host_id, tmux_session_name)
         WHERE tmux_session_name IS NOT NULL AND herdr_terminal_id IS NULL''',
      '''CREATE UNIQUE INDEX idx_sessions_herdr_pane
         ON session_records(host_id, tmux_session_name, herdr_terminal_id)
         WHERE herdr_terminal_id IS NOT NULL''',
    ],
  ),
];
