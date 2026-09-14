import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/conversation_shell/command_framer.dart';

void main() {
  const framer = ConversationCommandFramer();

  test('interactive child reads user stdin instead of RelayShell footer', () async {
    final process = await Process.start('/bin/sh', const []);
    addTearDown(() async {
      await process.stdin.close();
      process.kill();
    });

    final output = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(output.write);
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(output.write);
    addTearDown(stdoutDone.cancel);
    addTearDown(stderrDone.cancel);

    final frame = framer.build(
      nonce: 'interactive-test',
      id: '0',
      command: "IFS= read -r answer; printf 'agent:%s\\n' \"\$answer\"",
    );

    process.stdin.write(frame.payload);
    await process.stdin.flush();

    await _waitFor(() => output.toString().contains(frame.beginMarker));

    // If RelayShell's footer were still queued as later shell input, `read`
    // would consume that line here instead of waiting for this user message.
    expect(output.toString(), isNot(contains('agent:')));

    process.stdin.writeln('hello-herdr');
    await process.stdin.flush();

    await _waitFor(
      () => output.toString().contains(
        '${frame.endPrefix}0${ConversationCommandFramer.unitSeparator}',
      ),
    );

    final text = output.toString();
    expect(text, contains('agent:hello-herdr'));
    expect(text, isNot(contains('agent:__relayshell_status')));
  });

  test('framed commands preserve shell directory and environment state', () async {
    final process = await Process.start('/bin/sh', const []);
    addTearDown(() async {
      await process.stdin.close();
      process.kill();
    });

    final output = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(output.write);
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(output.write);
    addTearDown(stdoutDone.cancel);
    addTearDown(stderrDone.cancel);

    final mutate = framer.build(
      nonce: 'state-test',
      id: '0',
      command: 'cd /tmp; export RELAYSHELL_STATE=preserved',
    );
    process.stdin.write(mutate.payload);
    await process.stdin.flush();
    await _waitFor(
      () => output.toString().contains(
        '${mutate.endPrefix}0${ConversationCommandFramer.unitSeparator}',
      ),
    );

    final inspect = framer.build(
      nonce: 'state-test',
      id: '1',
      command: "printf 'state:%s:%s\\n' \"\$PWD\" \"\$RELAYSHELL_STATE\"",
    );
    process.stdin.write(inspect.payload);
    await process.stdin.flush();
    await _waitFor(
      () => output.toString().contains(
        '${inspect.endPrefix}0${ConversationCommandFramer.unitSeparator}',
      ),
    );

    expect(output.toString(), contains('state:/tmp:preserved'));
  });
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for shell protocol output.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
