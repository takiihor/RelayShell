import 'package:xterm/xterm.dart';

/// Interprets streamed terminal output instead of concatenating screen redraws.
/// One bounded emulator is retained for the active command only. It never sends
/// terminal replies: the session's real terminal owns the SSH input channel.
class TranscriptOutput {
  TranscriptOutput({int columns = 80, int rows = 24}) {
    terminal.resize(columns, rows);
  }

  final Terminal terminal = Terminal(maxLines: 4096);
  bool fullScreen = false;

  void write(String chunk) {
    terminal.write(chunk);
    fullScreen |= terminal.isUsingAltBuffer;
  }

  String get text {
    final buffer = terminal.buffer;
    var last = buffer.absoluteCursorY;
    for (var i = buffer.lines.length - 1; i > last; i--) {
      if (buffer.lines[i].getText().isNotEmpty) {
        last = i;
        break;
      }
    }
    final result = StringBuffer();
    for (var i = 0; i <= last; i++) {
      if (i > 0 && !buffer.lines[i].isWrapped) result.write('\n');
      result.write(buffer.lines[i].getText());
    }
    return result.toString();
  }
}
