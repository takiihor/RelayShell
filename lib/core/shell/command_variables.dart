import 'package:flutter/foundation.dart';

/// A `{{input:name}}` placeholder that must be filled before execution.
@immutable
class CommandInputRequest {
  const CommandInputRequest(this.name);

  final String name;

  /// A human-friendly prompt derived from the placeholder name.
  String get label {
    final spaced = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (spaced.isEmpty) return 'Value';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  bool operator ==(Object other) =>
      other is CommandInputRequest && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Result of substituting variables into a command template.
@immutable
class CommandSubstitution {
  const CommandSubstitution({
    required this.command,
    required this.unresolved,
  });

  /// The command with every resolvable placeholder replaced.
  final String command;

  /// Placeholders that had no value available. A command with unresolved
  /// placeholders must not be executed.
  final List<String> unresolved;

  bool get isComplete => unresolved.isEmpty;
}

/// Substitutes the small, fixed set of command variables from SPEC 13.2.
///
/// This is deliberately not a template language. It supports exactly three
/// forms and treats everything else as literal text:
///
/// * `{{project_path}}` — the project's remote path
/// * `{{host_name}}` — the computer's display name
/// * `{{input:name}}` — a value the user is prompted for
///
/// Substituted values are inserted verbatim. Callers that build a command for
/// the app's own use must quote the result; a user's saved command is
/// intentional shell input and is sent as configured (SPEC 29).
class CommandVariableResolver {
  const CommandVariableResolver();

  static final RegExp _placeholder = RegExp(r'\{\{\s*([a-zA-Z0-9_:.-]+)\s*\}\}');

  /// Known non-input variable names, so the UI can document them.
  static const Set<String> knownVariables = {
    'project_path',
    'project_name',
    'host_name',
    'host_hostname',
    'host_username',
    'working_directory',
  };

  /// Returns every `{{input:...}}` placeholder in [template], in first-use
  /// order and without duplicates.
  List<CommandInputRequest> inputsIn(String template) {
    final seen = <String>{};
    final result = <CommandInputRequest>[];
    for (final match in _placeholder.allMatches(template)) {
      final token = match.group(1)!;
      if (!token.startsWith('input:')) continue;
      final name = token.substring('input:'.length);
      if (name.isEmpty || !seen.add(name)) continue;
      result.add(CommandInputRequest(name));
    }
    return result;
  }

  /// Replaces placeholders in [template] using [context] for fixed variables
  /// and [inputs] for `{{input:...}}` values.
  CommandSubstitution resolve(
    String template, {
    Map<String, String?> context = const {},
    Map<String, String> inputs = const {},
  }) {
    final unresolved = <String>[];
    final command = template.replaceAllMapped(_placeholder, (match) {
      final token = match.group(1)!;
      if (token.startsWith('input:')) {
        final name = token.substring('input:'.length);
        final value = inputs[name];
        if (value == null) {
          unresolved.add(token);
          return match.group(0)!;
        }
        return value;
      }
      final value = context[token];
      if (value == null) {
        unresolved.add(token);
        return match.group(0)!;
      }
      return value;
    });
    return CommandSubstitution(command: command, unresolved: unresolved);
  }
}
