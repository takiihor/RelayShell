import 'package:flutter/foundation.dart';

import '../../core/shell/shell_quoting.dart';

/// Fully materialised framing for one Conversation Mode command.
@immutable
class ConversationCommandFrame {
  const ConversationCommandFrame({
    required this.payload,
    required this.beginMarker,
    required this.endPrefix,
  });

  /// Text typed into the live shell PTY.
  final String payload;

  /// Private marker emitted immediately before user-command output.
  final String beginMarker;

  /// Prefix of the private completion marker; exit status follows this text.
  final String endPrefix;
}

/// Builds the POSIX framing protocol used by Conversation Mode.
///
/// The protocol deliberately does not depend on PS1/prompt parsing. A random
/// per-controller nonce plus a monotonic command id makes marker collisions with
/// ordinary program output negligible.
class ConversationCommandFramer {
  const ConversationCommandFramer();

  static const String recordSeparator = '\x1e';
  static const String unitSeparator = '\x1f';

  ConversationCommandFrame build({
    required String nonce,
    required String id,
    required String command,
  }) {
    final token = '$nonce-$id';

    // Adjacent literals deliberately terminate each interpolation before the
    // next identifier-like text. This avoids both Dart interpolation ambiguity
    // (`$token__`) and unnecessary-brace / string-composition analyzer lints.
    final delimiter =
        '__RELAYSHELL_$token'
        '__';
    final begin =
        '$recordSeparator'
        'RELAYSHELL_BEGIN:$token'
        '$unitSeparator';
    final endPrefix =
        '$recordSeparator'
        'RELAYSHELL_END:$token:';

    // The command body is staged first so its text cannot be confused with
    // output. More importantly, eval + footer are one compound shell command
    // on one parser input line. The shell therefore parses the footer before
    // starting eval; an interactive child reading from the PTY cannot consume
    // RelayShell's own status/footer bytes as stdin.
    // Interactive Bash abandons the compound-command footer on Ctrl+C.
    // Report that exit from its SIGINT handler, then restore the caller's trap.
    // Other POSIX shells retain the ordinary footer path.
    const restoreInterrupt =
        r'if [ "${__relayshell_saved_int+x}" = x ]; then '
        r'trap - INT; eval "$__relayshell_saved_int"; '
        'unset __relayshell_saved_int; fi';
    final interruptHandler =
        "printf '\\036RELAYSHELL_END:$token:130\\037\\n'; "
        '$restoreInterrupt';
    final payload = StringBuffer()
      ..writeln('__relayshell_cmd="\$(cat <<\'$delimiter\'')
      ..writeln(command)
      ..writeln(delimiter)
      ..writeln(')"')
      ..write('{ ')
      ..write(
        'if [ -n "\$BASH_VERSION" ]; then '
        '__relayshell_saved_int=\$(trap -p INT); '
        'trap ${ShellQuoter.posix.quote(interruptHandler)} INT; fi; ',
      )
      ..write("printf '\\036RELAYSHELL_BEGIN:$token\\037\\n'; ")
      ..write('eval "\$__relayshell_cmd"; ')
      ..write('__relayshell_status=\$?; ')
      ..write(
        "printf '\\036RELAYSHELL_END:$token:%s\\037\\n' \"\$__relayshell_status\"; ",
      )
      ..write('if [ -n "\$BASH_VERSION" ]; then $restoreInterrupt; fi; ')
      ..writeln('unset __relayshell_cmd __relayshell_status; }');

    return ConversationCommandFrame(
      payload: payload.toString(),
      beginMarker: begin,
      endPrefix: endPrefix,
    );
  }
}
