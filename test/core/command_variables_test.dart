import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/command_variables.dart';

void main() {
  const resolver = CommandVariableResolver();

  group('inputsIn', () {
    test('finds input placeholders in first-use order', () {
      final inputs = resolver.inputsIn(
        'deploy {{input:environment}} --tag {{input:version}}',
      );
      expect(inputs.map((i) => i.name), ['environment', 'version']);
    });

    test('de-duplicates a placeholder used more than once', () {
      final inputs = resolver.inputsIn(
        'echo {{input:name}} && echo {{input:name}}',
      );
      expect(inputs, hasLength(1));
    });

    test('ignores non-input variables', () {
      expect(resolver.inputsIn('cd {{project_path}}'), isEmpty);
    });

    test('returns nothing for a plain command', () {
      expect(resolver.inputsIn('git status'), isEmpty);
    });

    test('builds a readable label from the placeholder name', () {
      final inputs = resolver.inputsIn('x {{input:target_branch}}');
      expect(inputs.single.label, 'Target branch');
    });
  });

  group('resolve', () {
    test('substitutes fixed context variables', () {
      final result = resolver.resolve(
        'cd {{project_path}} && echo {{host_name}}',
        context: {'project_path': '/srv/app', 'host_name': 'Home PC'},
      );
      expect(result.command, 'cd /srv/app && echo Home PC');
      expect(result.isComplete, isTrue);
    });

    test('substitutes user input', () {
      final result = resolver.resolve(
        'deploy {{input:environment}}',
        inputs: {'environment': 'staging'},
      );
      expect(result.command, 'deploy staging');
      expect(result.isComplete, isTrue);
    });

    test('tolerates whitespace inside the braces', () {
      final result = resolver.resolve(
        'cd {{ project_path }}',
        context: {'project_path': '/srv/app'},
      );
      expect(result.command, 'cd /srv/app');
    });

    test('reports unresolved variables and leaves them in place', () {
      final result = resolver.resolve(
        'cd {{project_path}}',
        context: {'project_path': null},
      );
      expect(result.isComplete, isFalse);
      expect(result.unresolved, ['project_path']);
      // The placeholder survives so the preview cannot look runnable.
      expect(result.command, 'cd {{project_path}}');
    });

    test('reports an unfilled input', () {
      final result = resolver.resolve('deploy {{input:env}}');
      expect(result.isComplete, isFalse);
      expect(result.unresolved, ['input:env']);
    });

    test('substitutes every occurrence of a repeated variable', () {
      final result = resolver.resolve(
        '{{input:x}} {{input:x}}',
        inputs: {'x': 'v'},
      );
      expect(result.command, 'v v');
    });

    test('leaves an unknown variable untouched and reports it', () {
      final result = resolver.resolve('echo {{not_a_variable}}');
      expect(result.command, 'echo {{not_a_variable}}');
      expect(result.unresolved, ['not_a_variable']);
    });

    test('does not treat single braces as a placeholder', () {
      const command = r'awk {print $1}';
      expect(resolver.resolve(command).command, command);
    });

    test('is not a template language: no expressions are evaluated', () {
      // Anything beyond the three supported forms is literal text (SPEC 13.2).
      const command = '{{ 1 + 1 }}';
      final result = resolver.resolve(command);
      expect(result.command, command);
    });

    test('leaves a command with no placeholders unchanged', () {
      expect(resolver.resolve('git status').command, 'git status');
    });

    test('inserts values verbatim, without quoting', () {
      // Documented behaviour: a saved command is intentional shell input, and
      // the caller quotes if it is building the command itself (SPEC 29).
      final result = resolver.resolve('echo {{input:x}}', inputs: {'x': 'a b'});
      expect(result.command, 'echo a b');
    });
  });
}
