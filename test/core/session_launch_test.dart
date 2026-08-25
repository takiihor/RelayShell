import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/session_launch.dart';
import 'package:relayshell/core/shell/tmux.dart';
import 'package:relayshell/shared/models/enums.dart';

void main() {
  const posix = SessionLaunchBuilder(
    platform: RemotePlatform.posix,
    prefix: 'rdc',
  );
  const powerShell = SessionLaunchBuilder(
    platform: RemotePlatform.windowsPowerShell,
    prefix: 'rdc',
  );

  group('directShell', () {
    test('opens a plain shell with no setup when there is no directory', () {
      final plan = posix.directShell();
      expect(plan.mode, SessionMode.direct);
      expect(plan.usesExec, isFalse);
      expect(plan.initialInput, isNull);
    });

    test('types the cd into the shell rather than exec-ing it', () {
      // Typed, so a missing directory leaves a usable prompt instead of
      // disconnecting the user.
      final plan = posix.directShell(workingDirectory: '/srv/my app');
      expect(plan.usesExec, isFalse);
      expect(plan.initialInput, "cd '/srv/my app'\n");
    });

    test('uses PowerShell syntax on a Windows host', () {
      final plan = powerShell.directShell(workingDirectory: r'C:\a b');
      expect(plan.initialInput, "Set-Location -LiteralPath 'C:\\a b'\n");
    });
  });

  group('directCommand', () {
    test('runs the command only after changing directory', () {
      final plan = posix.directCommand(
        'npm run dev',
        workingDirectory: '/srv/app',
      );
      expect(plan.initialInput, 'cd /srv/app && npm run dev\n');
    });

    test('uses conditional PowerShell sequencing after changing directory', () {
      final plan = powerShell.directCommand(
        'npm run dev',
        workingDirectory: r'C:\app',
      );
      expect(plan.initialInput, contains('if (\$?) { npm run dev }'));
    });

    test('runs the command alone with no directory', () {
      final plan = posix.directCommand('git status');
      expect(plan.initialInput, 'git status\n');
    });

    test('passes the user command through unmodified', () {
      // A saved command is intentional shell input (SPEC 29).
      const command = r'echo "$USER" | tee /tmp/out';
      final plan = posix.directCommand(command);
      expect(plan.initialInput, '$command\n');
    });
  });

  group('persistentSession', () {
    test('execs an atomic attach-or-create', () {
      final plan = posix.persistentSession(sessionName: 'rdc-api');
      expect(plan.mode, SessionMode.persistent);
      expect(plan.usesExec, isTrue);
      expect(plan.shellCommand, 'tmux new-session -A -s rdc-api');
      expect(plan.tmuxSessionName, 'rdc-api');
    });

    test('quotes the working directory', () {
      final plan = posix.persistentSession(
        sessionName: 'rdc-api',
        workingDirectory: '/srv/my app',
      );
      expect(plan.shellCommand, contains("-c '/srv/my app'"));
    });

    test('quotes a command to run inside the session', () {
      final plan = posix.persistentSession(
        sessionName: 'rdc-api',
        command: 'npm run dev',
      );
      expect(plan.shellCommand, endsWith("'npm run dev'"));
    });

    test('treats a blank command as no command', () {
      final plan = posix.persistentSession(
        sessionName: 'rdc-api',
        command: '   ',
      );
      expect(plan.shellCommand, 'tmux new-session -A -s rdc-api');
    });

    test('refuses on a platform without tmux', () {
      // Emitting `tmux ...` at a PowerShell prompt would be a confusing error
      // rather than a useful one, so this fails loudly instead (SPEC 30).
      expect(
        () => powerShell.persistentSession(sessionName: 'rdc-api'),
        throwsA(isA<TmuxUnavailableException>()),
      );
    });
  });

  group('resumeSession', () {
    test('reattaches without creating a duplicate', () {
      final plan = posix.resumeSession('rdc-api');
      expect(plan.shellCommand, 'tmux new-session -A -s rdc-api');
      expect(plan.mode, SessionMode.persistent);
    });

    test('refuses on a platform without tmux', () {
      expect(
        () => powerShell.resumeSession('rdc-api'),
        throwsA(isA<TmuxUnavailableException>()),
      );
    });
  });

  group('oneShot', () {
    test('returns the command unchanged with no directory', () {
      expect(posix.oneShot('df -h'), 'df -h');
    });

    test('prefixes a quoted cd, short-circuiting on failure', () {
      // `&&` matters: running the command in the wrong directory because cd
      // failed is worse than not running it.
      expect(
        posix.oneShot('df -h', workingDirectory: '/srv/my app'),
        "cd '/srv/my app' && df -h",
      );
    });

    test('uses PowerShell sequencing on a Windows host', () {
      final result = powerShell.oneShot('Get-Date', workingDirectory: r'C:\a');
      expect(result, contains('Set-Location -LiteralPath'));
      expect(result, contains(r'if ($?)'));
    });
  });

  group('sessionNameFor', () {
    test('generates a sanitised managed name', () {
      expect(
        posix.sessionNameFor(subject: 'GoByBus', action: 'Codex'),
        'rdc-gobybus-codex',
      );
    });

    test('avoids names already in use', () {
      expect(
        posix.sessionNameFor(subject: 'api', existingNames: {'rdc-api'}),
        'rdc-api-2',
      );
    });
  });
}
