import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/conversation_shell/transcript_output.dart';

void main() {
  test('every split of ANSI redraws produces the same readable result', () {
    const stream =
        'Downloading 10%\r\x1b[2KDownloading 100%\r\n'
        '\x1b[32m你好\x1b[0m\r\n';
    for (var split = 0; split <= stream.length; split++) {
      final output = TranscriptOutput();
      output.write(stream.substring(0, split));
      output.write(stream.substring(split));
      expect(output.text, 'Downloading 100%\n你好\n', reason: 'split $split');
    }
  });

  test('backspace edits and cursor-up redraws replace previous content', () {
    final output = TranscriptOutput();
    output.write('helo\blo\r\nold status\r\n');
    output.write('\x1b[1A\r\x1b[2Knew status');
    expect(output.text, 'hello\nnew status');
  });

  test(
    'split alternate screen uses terminal state and hides escape payloads',
    () {
      final output = TranscriptOutput();
      output.write('\x1b[?10');
      output.write('49h\x1b[HReady');
      expect(output.fullScreen, isTrue);
      expect(output.text, 'Ready');
      output.write('\x1b[?1049l');
      expect(output.fullScreen, isTrue);
    },
  );
}
