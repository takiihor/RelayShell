import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/tmux.dart';

void main() {
  const sep = TmuxCommandBuilder.fieldSeparator;

  group('sanitizeNameComponent', () {
    test('lower-cases and replaces runs of unsafe characters', () {
      expect(TmuxCommandBuilder.sanitizeNameComponent('GoByBus'), 'gobybus');
      expect(
        TmuxCommandBuilder.sanitizeNameComponent('My App (v2)'),
        'my-app-v2',
      );
    });

    test('removes characters tmux treats as addressing syntax', () {
      // tmux uses `:` and `.` for window/pane targets, so a name containing
      // them would address something else entirely.
      expect(
        TmuxCommandBuilder.sanitizeNameComponent('a:b.c'),
        'a-b-c',
      );
    });

    test('trims leading and trailing separators', () {
      expect(TmuxCommandBuilder.sanitizeNameComponent('  hello  '), 'hello');
      expect(TmuxCommandBuilder.sanitizeNameComponent('---x---'), 'x');
    });

    test('collapses to empty for input with nothing usable', () {
      expect(TmuxCommandBuilder.sanitizeNameComponent('!!!'), '');
    });

    test('handles non-ASCII by reducing it to separators', () {
      expect(
        TmuxCommandBuilder.sanitizeNameComponent('中文 project'),
        'project',
      );
    });
  });

  group('managedSessionName', () {
    test('joins prefix, subject and action', () {
      expect(
        TmuxCommandBuilder.managedSessionName(
          prefix: 'rdc',
          subject: 'GoByBus',
          action: 'Codex',
        ),
        'rdc-gobybus-codex',
      );
    });

    test('omits an absent or blank action', () {
      expect(
        TmuxCommandBuilder.managedSessionName(prefix: 'rdc', subject: 'Home PC'),
        'rdc-home-pc',
      );
      expect(
        TmuxCommandBuilder.managedSessionName(
          prefix: 'rdc',
          subject: 'Home PC',
          action: '   ',
        ),
        'rdc-home-pc',
      );
    });

    test('suffixes to avoid a collision', () {
      expect(
        TmuxCommandBuilder.managedSessionName(
          prefix: 'rdc',
          subject: 'api',
          existingNames: {'rdc-api'},
        ),
        'rdc-api-2',
      );
      expect(
        TmuxCommandBuilder.managedSessionName(
          prefix: 'rdc',
          subject: 'api',
          existingNames: {'rdc-api', 'rdc-api-2', 'rdc-api-3'},
        ),
        'rdc-api-4',
      );
    });

    test('falls back to a usable name when everything sanitises away', () {
      expect(
        TmuxCommandBuilder.managedSessionName(prefix: '!!', subject: '???'),
        'session',
      );
    });

    test('produces a name that needs no shell quoting', () {
      final name = TmuxCommandBuilder.managedSessionName(
        prefix: 'rdc',
        subject: r"weird'; rm -rf /",
      );
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(name), isTrue);
    });
  });

  group('parseSessions', () {
    const builder = TmuxCommandBuilder();

    test('parses a normal listing', () {
      final sessions = builder.parseSessions(
        'rdc-api${sep}3${sep}1${sep}1700000000\n'
        'rdc-logs${sep}1${sep}0${sep}1700000100\n',
      );

      expect(sessions, hasLength(2));
      expect(sessions[0].name, 'rdc-api');
      expect(sessions[0].windows, 3);
      expect(sessions[0].attached, isTrue);
      expect(
        sessions[0].created,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
      expect(sessions[1].attached, isFalse);
    });

    test('returns nothing for empty output', () {
      expect(builder.parseSessions(''), isEmpty);
      expect(builder.parseSessions('\n\n'), isEmpty);
    });

    test('skips malformed lines instead of discarding the whole listing', () {
      final sessions = builder.parseSessions(
        'garbage line with no separators\n'
        'rdc-good${sep}2${sep}0${sep}1700000000\n',
      );
      expect(sessions, hasLength(1));
      expect(sessions.single.name, 'rdc-good');
    });

    test('tolerates a missing created field', () {
      final sessions = builder.parseSessions('rdc-api${sep}1${sep}0');
      expect(sessions, hasLength(1));
      expect(sessions.single.created, isNull);
    });

    test('defaults unparseable numbers rather than throwing', () {
      final sessions = builder.parseSessions('rdc-api${sep}x${sep}y${sep}z');
      expect(sessions.single.windows, 1);
      expect(sessions.single.attached, isFalse);
      expect(sessions.single.created, isNull);
    });

    test('keeps session names containing spaces intact', () {
      // The separator is a control character, so a space in a name is safe.
      final sessions = builder.parseSessions('my session${sep}1${sep}0');
      expect(sessions.single.name, 'my session');
    });
  });

  group('command construction', () {
    const builder = TmuxCommandBuilder();

    test('attach-or-create is a single atomic command', () {
      expect(
        builder.attachOrCreate('rdc-api'),
        'tmux new-session -A -s rdc-api',
      );
    });

    test('quotes the working directory', () {
      expect(
        builder.attachOrCreate('rdc-api', workingDirectory: '/srv/my app'),
        "tmux new-session -A -s rdc-api -c '/srv/my app'",
      );
    });

    test('quotes a command run inside the session', () {
      expect(
        builder.attachOrCreateRunning('rdc-api', 'npm run dev'),
        "tmux new-session -A -s rdc-api 'npm run dev'",
      );
    });

    test('quotes names in management commands', () {
      expect(
        builder.killSession('weird name'),
        "tmux kill-session -t 'weird name'",
      );
      expect(
        builder.renameSession('a b', 'c d'),
        "tmux rename-session -t 'a b' 'c d'",
      );
    });

    test('list-sessions exits 127 when tmux is missing', () {
      // The caller distinguishes "no sessions" from "no tmux" by this code.
      expect(builder.listSessions(), contains('exit 127'));
    });

    test('detect prints a marker when tmux is absent', () {
      expect(builder.detect(), contains('__NO_TMUX__'));
    });
  });

  group('TmuxSession', () {
    test('recognises sessions this app manages', () {
      const managed =
          TmuxSession(name: 'rdc-api', windows: 1, attached: false);
      const foreign =
          TmuxSession(name: 'my-own-session', windows: 1, attached: false);

      expect(managed.isManagedBy('rdc'), isTrue);
      expect(foreign.isManagedBy('rdc'), isFalse);
    });

    test('does not treat a prefix substring as managed', () {
      const other =
          TmuxSession(name: 'rdcextra', windows: 1, attached: false);
      expect(other.isManagedBy('rdc'), isFalse);
    });
  });
}
