import 'package:flutter/foundation.dart';

/// One reason a command looked destructive.
@immutable
class DangerSignal {
  const DangerSignal({required this.pattern, required this.explanation});

  /// A short label for the matched construct, e.g. `rm -rf`.
  final String pattern;

  /// Plain-language description of what could go wrong.
  final String explanation;
}

/// Heuristic assessment of a command's destructive potential (SPEC 13.3).
///
/// This is explicitly a *hint*, never a guarantee. [DangerAnalyzer] can only
/// recognise shapes it has been taught; a clean result says nothing about
/// whether a command is safe, and the UI must never present it as such.
@immutable
class DangerAssessment {
  const DangerAssessment(this.signals);

  const DangerAssessment.none() : signals = const [];

  final List<DangerSignal> signals;

  bool get hasSignals => signals.isNotEmpty;
}

/// Matches shapes that are destructive often enough to be worth a second tap.
///
/// Kept small and specific on purpose. A detector that fires on everything
/// trains users to dismiss it, which is worse than not having one.
class DangerAnalyzer {
  const DangerAnalyzer();

  static final List<_Rule> _rules = [
    _Rule(
      RegExp(r'\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*\s+)*-[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*\s+-[a-zA-Z]*[rR]'),
      'rm -rf',
      'Recursively force-deletes files without prompting.',
    ),
    _Rule(
      RegExp(r'\brm\s+.*\s(/|/\*|~|~/\*)\s*$'),
      'rm at filesystem root',
      'Targets the root or home directory itself.',
    ),
    _Rule(
      RegExp(r'\bmkfs(\.\w+)?\b'),
      'mkfs',
      'Formats a filesystem, erasing everything on the device.',
    ),
    _Rule(
      RegExp(r'\bdd\b[^|]*\bof=/dev/'),
      'dd to a device',
      'Writes raw data directly to a block device.',
    ),
    _Rule(
      RegExp(r'>\s*/dev/(sd|nvme|hd|vd)\w'),
      'redirect to a device',
      'Overwrites a raw disk device.',
    ),
    _Rule(
      RegExp(r'\bshred\b'),
      'shred',
      'Irreversibly overwrites file contents.',
    ),
    _Rule(
      RegExp(r':\(\)\s*\{\s*:\|:&\s*\}\s*;\s*:'),
      'fork bomb',
      'Spawns processes without limit until the machine stops responding.',
    ),
    _Rule(
      RegExp(r'\bchmod\s+(-[a-zA-Z]+\s+)*(777|-R\s+777)'),
      'chmod 777',
      'Grants write access to every user on the machine.',
    ),
    _Rule(
      RegExp(r'\bchown\s+-[a-zA-Z]*R[a-zA-Z]*\s+.*\s/(\s|$)'),
      'recursive chown of /',
      'Rewrites ownership across the whole filesystem.',
    ),
    _Rule(
      RegExp(r'\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z|k|)sh\b'),
      'pipe download to shell',
      'Executes a script straight from the network without review.',
    ),
    _Rule(
      RegExp(r'\bgit\s+(reset\s+--hard|clean\s+-[a-zA-Z]*f|push\s+.*--force(-with-lease)?\b)'),
      'destructive git',
      'Discards local work or rewrites published history.',
    ),
    _Rule(
      RegExp(r'\bdocker\s+(system\s+prune|volume\s+rm|rm\s+-f)\b'),
      'docker removal',
      'Removes containers, volumes or images and any data inside them.',
    ),
    _Rule(
      RegExp(r'\bdrop\s+(database|table|schema)\b', caseSensitive: false),
      'SQL DROP',
      'Deletes a database object and its contents.',
    ),
    _Rule(
      RegExp(r'\btruncate\s+table\b', caseSensitive: false),
      'SQL TRUNCATE',
      'Empties a table.',
    ),
    _Rule(
      // Anchored to the command position — at the start, after a separator, or
      // after `sudo` — so that searching *for* the word "reboot" in a file does
      // not get flagged as rebooting the machine.
      RegExp(r'(^|[;&|]\s*|\bsudo\s+)(shutdown|reboot|halt|poweroff)\b'),
      'power state change',
      'Shuts down or restarts the computer, ending your session.',
    ),
    _Rule(
      RegExp(r'\bkill(all)?\s+-9\b'),
      'kill -9',
      'Terminates processes without letting them save state.',
    ),
    _Rule(
      RegExp(r'\bRemove-Item\b[^|]*-Recurse[^|]*-Force', caseSensitive: false),
      'Remove-Item -Recurse -Force',
      'Recursively force-deletes items without prompting.',
    ),
    _Rule(
      RegExp(r'\bFormat-Volume\b', caseSensitive: false),
      'Format-Volume',
      'Formats a volume, erasing everything on it.',
    ),
  ];

  /// Scans [command] for known destructive shapes.
  DangerAssessment analyze(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return const DangerAssessment.none();

    final signals = <DangerSignal>[];
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(trimmed)) {
        signals.add(
          DangerSignal(pattern: rule.label, explanation: rule.explanation),
        );
      }
    }
    return DangerAssessment(signals);
  }
}

class _Rule {
  _Rule(this.pattern, this.label, this.explanation);

  final RegExp pattern;
  final String label;
  final String explanation;
}
