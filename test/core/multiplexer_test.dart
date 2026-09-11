import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/multiplexer.dart';
import 'package:relayshell/core/shell/multiplexer_session.dart';
import 'package:relayshell/core/shell/shell_quoting.dart';
import 'package:relayshell/shared/models/enums.dart';

/// Recovers the command a login-shell wrapper will actually run.
///
/// `loginShell` quotes its payload for the outer shell, so asserting on the
/// wrapped string means asserting on POSIX escaping. Unwrapping keeps the tests
/// about the command.
String innerCommand(String wrapped) {
  final match = RegExp(r"-l -c '(.*)'$", dotAll: true).firstMatch(wrapped);
  if (match == null) return wrapped;
  return match.group(1)!.replaceAll(r"'\''", "'");
}

void main() {
  group('backend selection', () {
    test('maps every kind to an implementation', () {
      for (final kind in MultiplexerKind.values) {
        expect(Multiplexer.of(kind, quoter: ShellQuoter.posix).kind, kind);
      }
    });

    test('a POSIX host gets a POSIX quoter', () {
      final backend = Multiplexer.forPlatform(
        MultiplexerKind.herdr,
        RemotePlatform.posix,
      );
      expect(
        innerCommand(backend.attachOrCreate('my session')),
        "herdr --session 'my session'",
      );
    });
  });

  group('detach bindings', () {
    test('each backend sends its own key after the shared prefix', () {
      // Both use Ctrl+B as the prefix, so sending tmux's `d` to Herdr would do
      // something else entirely rather than nothing.
      expect(const TmuxMultiplexer().detachSequence, '\x02d');
      expect(const HerdrMultiplexer().detachSequence, '\x02q');
    });
  });

  group('HerdrMultiplexer', () {
    const backend = HerdrMultiplexer();

    test('attach-or-create launches or attaches in one step', () {
      expect(
        backend.attachOrCreate('rdc-api'),
        'exec "\${SHELL:-/bin/sh}" -l -c \'herdr --session rdc-api\'',
      );
    });

    test('runs through a login shell so PATH includes ~/.local/bin', () {
      // The usual Herdr install lands in ~/.local/bin, which an SSH exec
      // channel does not have on PATH -- without this, Herdr is "command not
      // found" on a machine where it is installed and running.
      for (final command in [
        backend.attachOrCreate('rdc-api'),
        backend.listSessions(),
        backend.detect(),
        backend.hasSession('rdc-api'),
        backend.killSession('rdc-api'),
      ]) {
        expect(command, startsWith('exec "\${SHELL:-/bin/sh}" -l -c '));
      }
    });

    test('never exec-s a compound command', () {
      // `exec` takes a single simple command; `exec cd x && y` is a syntax
      // error, so only the login shell itself is exec'd.
      expect(backend.listSessions(), isNot(contains("-c 'exec ")));
      expect(
        backend.attachOrCreate('a', workingDirectory: '/tmp'),
        isNot(contains("-c 'exec ")),
      );
    });

    test('quotes a session name that needs it', () {
      expect(
        innerCommand(backend.attachOrCreate('my session')),
        "herdr --session 'my session'",
      );
    });

    test('applies a working directory by cd-ing first, short-circuiting', () {
      // Herdr has no -c equivalent, and `&&` means a bad path fails loudly
      // instead of silently starting the session somewhere else.
      expect(
        innerCommand(
          backend.attachOrCreate('rdc-api', workingDirectory: '/srv/my app'),
        ),
        "cd '/srv/my app' && herdr --session rdc-api",
      );
    });

    test('reports that it cannot run a command at create time', () {
      // `herdr --session` takes no startup command, so the launch builder types
      // the command in instead of appending something Herdr would ignore.
      expect(backend.supportsStartupCommand, isFalse);
      expect(
        () => backend.attachOrCreateRunning('rdc-api', 'npm run dev'),
        throwsUnsupportedError,
      );
    });

    test('reports that it cannot rename a live session', () {
      expect(backend.supportsRename, isFalse);
      expect(() => backend.renameSession('a', 'b'), throwsUnsupportedError);
    });

    test('list-sessions exits 127 only when herdr is missing', () {
      // A machine with Herdr installed but no server running must not look like
      // a machine without Herdr.
      final command = backend.listSessions();
      expect(command, contains('exit 127'));
      expect(command, contains('|| true'));
    });

    test('detect prints the shared marker when herdr is absent', () {
      expect(backend.detect(), contains(Multiplexer.missingSentinel));
    });

    group('parseSessions', () {
      test('reads the real shape of `herdr session list --json`', () {
        const output =
            '{"sessions":[{"default":true,"name":"default",'
            '"running":true,"session_dir":"/home/dev/.config/herdr",'
            '"socket_path":"/home/dev/.config/herdr/herdr.sock"}]}';

        final sessions = backend.parseSessions(output);
        expect(sessions, hasLength(1));
        expect(sessions.single.name, 'default');
        expect(sessions.single.attached, isTrue);
        expect(sessions.single.directory, '/home/dev/.config/herdr');
      });

      test('reads several sessions and a stopped one', () {
        const output =
            '{"sessions":[{"name":"a","running":true},'
            '{"name":"b","running":false}]}';

        final sessions = backend.parseSessions(output);
        expect(sessions.map((s) => s.name), ['a', 'b']);
        expect(sessions.last.attached, isFalse);
      });

      test('degrades to no sessions rather than throwing on junk', () {
        // A truncated or unexpected response must not take out the session list.
        for (final junk in ['', '   ', 'not json', '{"sessions":[', '{}']) {
          expect(backend.parseSessions(junk), isEmpty, reason: junk);
        }
      });

      test('skips entries with no usable name', () {
        expect(backend.parseSessions('{"sessions":[{"running":true}]}'), isEmpty);
      });
    });

    test('management commands quote the session name', () {
      expect(
        innerCommand(backend.killSession('weird name')),
        "herdr session stop 'weird name'",
      );
    });
  });

  group('managed session names', () {
    test('both backends agree on the generated name', () {
      // The name is stored locally and matched against the remote list, so the
      // two backends must not drift.
      const subject = 'My App (v2)';
      expect(
        const HerdrMultiplexer().managedSessionName(
          prefix: 'rdc',
          subject: subject,
        ),
        const TmuxMultiplexer().managedSessionName(
          prefix: 'rdc',
          subject: subject,
        ),
      );
    });
  });

  group('MultiplexerSession', () {
    test('identity is the name, whichever backend reported it', () {
      const a = MultiplexerSession(name: 'x', windows: 0, attached: true);
      const b = MultiplexerSession(name: 'x', windows: 3, attached: false);
      expect(a, b);
    });
  });
}
