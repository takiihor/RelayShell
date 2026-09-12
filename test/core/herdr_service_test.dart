import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/ssh/herdr_service.dart';

void main() {
  String frame(int seq, String text, {bool full = true}) =>
      '${jsonEncode({'type': 'terminal.frame', 'seq': seq, 'encoding': 'ansi', 'width': 80, 'height': 24, 'full': full, 'bytes': base64Encode(utf8.encode(text))})}\n';

  test('decodes every NDJSON split without duplicating frames', () {
    final stream = frame(1, '\x1b[2J你好 👋') + frame(2, 'next', full: false);
    for (var split = 0; split <= stream.length; split++) {
      final output = <String>[];
      final decoder = HerdrStreamDecoder(onFrame: output.add, onClosed: (_) {});
      decoder.add(stream.substring(0, split));
      decoder.add(stream.substring(split));
      decoder.finish();
      expect(output, ['\x1b[2J你好 👋', 'next']);
    }
  });

  test(
    'requires a full baseline and rejects lost or replayed delta frames',
    () {
      final decoder = HerdrStreamDecoder(onFrame: (_) {}, onClosed: (_) {});
      expect(
        () => decoder.add(frame(1, '', full: false)),
        throwsFormatException,
      );
      decoder.add(frame(1, 'initial'));
      expect(
        () => decoder.add(frame(3, '', full: false)),
        throwsFormatException,
      );
      decoder.add(frame(4, 'new baseline'));
      expect(() => decoder.add(frame(4, 'replay')), throwsFormatException);
    },
  );

  test('bounds malformed records and rejects incomplete or invalid data', () {
    final decoder = HerdrStreamDecoder(onFrame: (_) {}, onClosed: (_) {});
    expect(
      () => decoder.add('x' * (HerdrStreamDecoder.maxRecordCharacters + 1)),
      throwsFormatException,
    );
    decoder.add('{"type":');
    expect(decoder.finish, throwsFormatException);
    final invalid = HerdrStreamDecoder(onFrame: (_) {}, onClosed: (_) {});
    expect(() => invalid.add('{"type":"wrong"}\n'), throwsFormatException);
  });

  test('closed streams stop rendering; input remains one JSON record', () {
    final output = <String>[];
    final reasons = <String>[];
    final decoder = HerdrStreamDecoder(
      onFrame: output.add,
      onClosed: reasons.add,
    );
    decoder.add(
      '{"type":"terminal.closed","reason":"detached"}\n${frame(1, 'ignored')}',
    );
    expect(output, isEmpty);
    expect(reasons, ['detached']);
    const input = '"quoted"\n你好\x03';
    final encoded = HerdrStreamDecoder.input(input);
    expect(encoded.split('\n'), hasLength(2));
    expect(jsonDecode(encoded)['text'], input);
    expect(jsonDecode(HerdrStreamDecoder.scroll(true))['source'], 'page_key');
  });

  test('pane discovery keeps stable terminal IDs and actual agent status', () {
    final panes = HerdrService.parsePanes(
      jsonEncode({
        'result': {
          'panes': [
            {
              'pane_id': 'w2:p7',
              'terminal_id': 'term_stable',
              'label': 'Daily work',
              'agent': 'codex',
              'agent_status': 'blocked',
              'cwd': '/old',
              'foreground_cwd': '/project',
            },
          ],
        },
      }),
    );
    expect(panes.single.terminalId, 'term_stable');
    expect(panes.single.status, 'blocked');
    expect(panes.single.directory, '/project');
    expect(
      () => HerdrService.parsePanes('{"error":"offline"}'),
      throwsFormatException,
    );
    final plan = HerdrService.attach('daily', panes.single.terminalId);
    expect(plan.initialInput, isNull);
    expect(plan.shellCommand, contains('terminal session control term_stable'));
    expect(plan.shellCommand, isNot(contains('--takeover')));
  });
}
