import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/conversation_shell/conversation_session.dart';

void main() {
  late ConversationSession shell;
  late List<String> sent;
  String marker(String body) => '\x1b]777;RS:${shell.nonce}:$body\x07';

  setUp(() {
    shell = ConversationSession();
    sent = [];
    shell.send = sent.add;
    shell.addOutput(marker('E:0:0'));
  });
  tearDown(() => shell.dispose());

  test('every split of markers, ANSI and Unicode preserves command output', () {
    for (var split = 0; split < 140; split++) {
      final model = ConversationSession(nonce: 'test');
      model.send = (_) {};
      model.addOutput('\x1b]777;RS:test:E:0:0\x07');
      expect(model.submit('echo hello'), isTrue);
      const stream =
          'echoed wrapper\r\n\x1b]777;RS:test:B:1\x07'
          '\x1b[32m你好 👋\x1b[0m\r\n'
          '\x1b]777;RS:other:E:1:0\x07'
          '\x1b]777;RS:test:E:1:7\x07prompt';
      final bytes = utf8.encode(stream);
      final at = split.clamp(0, bytes.length);
      final decoder = utf8.decoder.startChunkedConversion(
        StringConversionSink.fromStringSink(_OutputSink(model.addOutput)),
      );
      decoder.add(bytes.sublist(0, at));
      decoder.add(bytes.sublist(at));
      decoder.close();
      expect(model.commands.single.output, '你好 👋\n', reason: 'split $split');
      expect(model.commands.single.exitCode, 7);
      expect(model.ready, isTrue);
      model.dispose();
    }
  });

  test(
    'streams before completion, serializes submissions and ignores wrong IDs',
    () {
      expect(shell.submit('first'), isTrue);
      expect(shell.submit('second'), isFalse);
      shell.addOutput('${marker('B:1')}hello');
      expect(shell.commands.single.output, 'hello');
      shell.addOutput(marker('E:2:0'));
      expect(shell.active, isNotNull);
      shell.addOutput(marker('E:1:0'));
      expect(shell.submit('second'), isTrue);
      shell.addOutput('${marker('B:2')}world${marker('E:2:1')}');
      expect(shell.commands.map((e) => e.output), ['hello', 'world']);
      expect(shell.commands.last.exitCode, 1);
    },
  );

  test('missing begin or malformed end cannot fabricate a result', () {
    shell.submit('test');
    shell.addOutput(marker('E:1:0'));
    expect(shell.active, isNotNull);
    shell.addOutput(
      '${marker('B:1')}${marker('E:1:invalid')}${marker('E:1:999')}',
    );
    expect(shell.active, isNotNull);
    shell.disconnected();
    expect(shell.commands.single.state, ConversationCommandState.unknown);
    expect(shell.commands.single.exitCode, isNull);
    expect(shell.ready, isFalse);
  });

  test('interrupt sends Ctrl+C and waits for confirmed shell status', () {
    shell.submit('sleep 30');
    shell.addOutput(marker('B:1'));
    shell.interrupt();
    expect(sent.last, '\x03');
    expect(shell.active, isNotNull);
    shell.addOutput(marker('E:1:130'));
    expect(shell.commands.single.state, ConversationCommandState.interrupted);
    expect(shell.ready, isTrue);
  });

  test('bounds output and transcript; clear retains the running command', () {
    for (var i = 1; i <= 60; i++) {
      shell.submit('echo $i');
      shell.addOutput('${marker('B:$i')}${'x' * 50000}${marker('E:$i:0')}');
    }
    expect(shell.commands.length, ConversationSession.maxCommands);
    expect(shell.commands.first.command, 'echo 11');
    expect(
      shell.commands.last.output.length,
      ConversationSession.maxOutputCharacters,
    );
    expect(shell.commands.last.truncated, isTrue);
    shell.submit('sleep 30');
    shell.clear();
    expect(shell.commands.single, shell.active);
  });

  test(
    'alternate screen detection and terminal handoff never resend a command',
    () {
      shell.submit('vim');
      shell.addOutput('${marker('B:1')}\x1b[?10');
      shell.addOutput('49h');
      expect(shell.active!.interactive, isTrue);
      final count = sent.length;
      shell.terminalInput();
      shell.addOutput(marker('E:1:0'));
      expect(sent.length, count);
      expect(shell.ready, isFalse);
      expect(shell.unavailable, isTrue);
    },
  );

  test('malformed oversized OSC cannot consume unbounded parser memory', () {
    shell.submit('test');
    shell.addOutput('${marker('B:1')}\x1b]${'x' * 100000}\x07visible');
    shell.addOutput(marker('E:1:0'));
    expect(shell.commands.single.output, 'visible');
  });

  test(
    'quotes multiline and control input without sending terminal keystrokes',
    () {
      final quoted = ConversationSession.quoteCommand("echo 'x'\n\t\x03\x1b\\");
      expect(quoted, isNot(contains('\n')));
      expect(quoted, isNot(contains('\t')));
      expect(quoted, isNot(contains('\x03')));
      expect(quoted, isNot(contains('\x1b')));
      expect(() => shell.submit('a\x00b'), throwsArgumentError);
      expect(shell.commands, isEmpty);
    },
  );

  test('real Bash PTY preserves directory, exports, functions, aliases and activation', () async {
    shell.dispose();
    shell = ConversationSession();
    final process = await Process.start(
      'script',
      [
        '-q',
        '-f',
        '-c',
        shell.launchPlan(workingDirectory: '/tmp').shellCommand!,
        '/dev/null',
      ],
      environment: {'TERM': 'xterm-256color'},
    );
    final stdout = process.stdout
        .transform(utf8.decoder)
        .listen(shell.addOutput);
    final stderr = process.stderr
        .transform(utf8.decoder)
        .listen(shell.addOutput);
    shell.send = (data) => process.stdin.write(data);
    try {
      await _until(() => shell.ready);
      Future<ConversationCommand> run(String command) async {
        expect(shell.submit(command), isTrue);
        await process.stdin.flush();
        await _until(() => shell.active == null);
        return shell.commands.last;
      }

      await run('cd /');
      await run('export RELAYSHELL_TEST="hello 世界"');
      await run("greet() { printf '%s\\n' \"\$RELAYSHELL_TEST\"; }");
      await run("alias rs_hello='greet'");
      await run(
        "source /dev/stdin <<'EOF'\nexport VIRTUAL_ENV=/tmp/example-venv\nEOF",
      );
      final result = await run(r'pwd; rs_hello; echo "$VIRTUAL_ENV"');
      expect(result.output, contains('/\nhello 世界\n/tmp/example-venv'));
      expect(result.exitCode, 0);
      expect((await run('false')).exitCode, 1);
      expect((await run(r'echo $?')).output, '1\n');
      expect(
        (await run('''printf '%s' "quote '"''')).output,
        contains("quote '"),
      );
      expect(shell.submit('sleep 30'), isTrue);
      await process.stdin.flush();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      shell.interrupt();
      await process.stdin.flush();
      await _until(() => shell.active == null);
      expect(shell.commands.last.state, ConversationCommandState.interrupted);
      expect((await run('echo still-alive')).output, contains('still-alive'));
    } finally {
      process.stdin.write('exit\n');
      await process.stdin.flush();
      await process.stdin.close();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      await stdout.cancel();
      await stderr.cancel();
    }
  }, skip: !Platform.isLinux);
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Shell did not reach expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _OutputSink implements StringSink {
  _OutputSink(this.add);
  final void Function(String) add;
  @override
  void write(Object? object) => add('$object');
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      add(objects.join(separator));
  @override
  void writeCharCode(int charCode) => add(String.fromCharCode(charCode));
  @override
  void writeln([Object? object = '']) => add('$object\n');
}
