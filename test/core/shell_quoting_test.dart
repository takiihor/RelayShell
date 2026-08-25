import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/shell_quoting.dart';
import 'package:relayshell/shared/models/enums.dart';

void main() {
  group('PosixShellQuoter', () {
    const quoter = PosixShellQuoter();

    test('leaves safe words unquoted', () {
      expect(quoter.quote('projects'), 'projects');
      expect(quoter.quote('/home/user/dev'), '/home/user/dev');
      expect(quoter.quote('file-name_2.txt'), 'file-name_2.txt');
    });

    test('quotes spaces', () {
      expect(quoter.quote('My Project'), "'My Project'");
    });

    test('quotes shell metacharacters so they cannot execute', () {
      expect(quoter.quote(r'a;rm -rf /'), "'a;rm -rf /'");
      expect(quoter.quote(r'$(whoami)'), r"'$(whoami)'");
      expect(quoter.quote('`id`'), "'`id`'");
      expect(quoter.quote('a && b'), "'a && b'");
      expect(quoter.quote('a|b'), "'a|b'");
      expect(quoter.quote(r'a>b'), "'a>b'");
      expect(quoter.quote('*'), "'*'");
    });

    test('escapes an embedded single quote by closing and reopening', () {
      // The canonical POSIX form: 'it'\''s'
      expect(quoter.quote("it's"), r"'it'\''s'");
    });

    test('quotes the empty string', () {
      expect(quoter.quote(''), "''");
    });

    test('rejects newlines that would split the command', () {
      expect(
        () => quoter.quote('a\nrm -rf /'),
        throwsA(isA<UnquotableArgumentError>()),
      );
      expect(
        () => quoter.quote('a\rb'),
        throwsA(isA<UnquotableArgumentError>()),
      );
    });

    test('rejects NUL bytes', () {
      expect(
        () => quoter.quote('a\u0000b'),
        throwsA(isA<UnquotableArgumentError>()),
      );
    });

    test('builds a cd command with the path quoted', () {
      expect(quoter.changeDirectory('/a b/c'), "cd '/a b/c'");
    });

    test('sequences with short-circuit and', () {
      expect(quoter.andThen('cd /x', 'ls'), 'cd /x && ls');
    });
  });

  group('PowerShellQuoter', () {
    const quoter = PowerShellQuoter();

    test('wraps in single quotes', () {
      expect(quoter.quote(r'C:\Users\dev'), r"'C:\Users\dev'");
      expect(quoter.quote('My Project'), "'My Project'");
    });

    test('doubles an embedded single quote', () {
      expect(quoter.quote("it's"), "'it''s'");
    });

    test('a single quote cannot break out', () {
      final quoted = quoter.quote("'; Remove-Item -Recurse -Force C:\\; '");
      expect(quoted.startsWith("'"), isTrue);
      expect(quoted.endsWith("'"), isTrue);
      // Every interior quote is doubled, so none of them closes the string.
      final interior = quoted.substring(1, quoted.length - 1);
      expect(interior.replaceAll("''", ''), isNot(contains("'")));
    });

    test('does not expand variables inside single quotes', () {
      expect(quoter.quote(r'$env:PATH'), r"'$env:PATH'");
    });

    test('uses Set-Location with a literal path', () {
      expect(
        quoter.changeDirectory(r'C:\a b'),
        r"Set-Location -LiteralPath 'C:\a b'",
      );
    });
  });

  group('WindowsCmdQuoter', () {
    const quoter = WindowsCmdQuoter();

    test('wraps in double quotes', () {
      expect(quoter.quote(r'C:\Users\dev'), r'"C:\Users\dev"');
    });

    test('refuses percent, which cmd.exe cannot escape', () {
      expect(
        () => quoter.quote('%PATH%'),
        throwsA(isA<UnquotableArgumentError>()),
      );
    });

    test('refuses delayed-expansion bang', () {
      expect(
        () => quoter.quote('a!b!'),
        throwsA(isA<UnquotableArgumentError>()),
      );
    });

    test('refuses an embedded double quote rather than mangling it', () {
      expect(
        () => quoter.quote('a"b'),
        throwsA(isA<UnquotableArgumentError>()),
      );
    });
  });

  // The property that actually matters is that a real shell parses the quoted
  // form back into exactly the original string — one argument, unexpanded,
  // nothing executed. Asserting against /bin/sh tests that directly instead of
  // re-implementing the shell's parser in the expectation.
  group('PosixShellQuoter round-trips through /bin/sh', () {
    const quoter = PosixShellQuoter();

    Future<String> shellEcho(String quoted) async {
      final result = await Process.run('/bin/sh', ['-c', 'printf %s $quoted']);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return result.stdout as String;
    }

    final hostile = <String>[
      'plain',
      'My Project',
      "it's",
      r"'; rm -rf /; echo '",
      r'$(whoami)',
      '`id`',
      r'$HOME',
      'a && b || c',
      'a; b',
      'a|b',
      'a>b<c',
      '*',
      '?',
      '[a-z]',
      '~/projects',
      r'back\slash',
      '"double"',
      'tab\there',
      '#comment',
      '!history',
      'unicode: \u00e9\u4e2d\u6587',
      '',
    ];

    for (final value in hostile) {
      test('preserves ${value.isEmpty ? '(empty)' : value}', () async {
        expect(await shellEcho(quoter.quote(value)), value);
      });
    }

    test('a quoted path stays a single argument', () async {
      // `set -- <quoted>` then `$#` reports how many arguments the shell saw.
      final quoted = quoter.quote('/home/a b/c d');
      final result = await Process.run('/bin/sh', [
        '-c',
        'set -- $quoted; printf %s "\$#"',
      ]);
      expect(result.stdout, '1');
    });
  }, skip: !Platform.isLinux && !Platform.isMacOS);

  group('ShellQuoter.forPlatform', () {
    test('maps each platform to its quoting rules', () {
      expect(
        ShellQuoter.forPlatform(RemotePlatform.posix),
        isA<PosixShellQuoter>(),
      );
      expect(
        ShellQuoter.forPlatform(RemotePlatform.windowsPowerShell),
        isA<PowerShellQuoter>(),
      );
      expect(
        ShellQuoter.forPlatform(RemotePlatform.windowsCmd),
        isA<WindowsCmdQuoter>(),
      );
    });
  });
}
