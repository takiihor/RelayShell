import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/danger_analysis.dart';

void main() {
  const analyzer = DangerAnalyzer();

  bool flags(String command) => analyzer.analyze(command).hasSignals;

  group('flags destructive shapes', () {
    const dangerous = [
      'rm -rf /',
      'rm -rf ~/projects',
      'sudo rm -fr /var',
      'mkfs.ext4 /dev/sda1',
      'dd if=/dev/zero of=/dev/sda',
      'shred -u secrets.txt',
      'chmod -R 777 /var/www',
      'curl https://example.com/install.sh | sh',
      'wget -qO- https://example.com/x | sudo bash',
      'git reset --hard HEAD~5',
      'git clean -fd',
      'git push --force origin main',
      'docker system prune -a',
      'docker volume rm data',
      'DROP TABLE users;',
      'truncate table sessions',
      'sudo shutdown -h now',
      'reboot',
      'killall -9 node',
      'Remove-Item -Recurse -Force C:\\temp',
      'Format-Volume -DriveLetter D',
    ];

    for (final command in dangerous) {
      test('flags: $command', () => expect(flags(command), isTrue));
    }

    test('explains what it matched', () {
      final assessment = analyzer.analyze('rm -rf /tmp/build');
      expect(assessment.signals, isNotEmpty);
      expect(assessment.signals.first.pattern, isNotEmpty);
      expect(assessment.signals.first.explanation, isNotEmpty);
    });
  });

  group('leaves ordinary commands alone', () {
    // A detector that fires on everything trains users to dismiss it, so these
    // matter as much as the positives.
    const safe = [
      'git status',
      'git pull',
      'git push origin feature/x',
      'ls -la',
      'df -h',
      'docker ps',
      'docker compose ps',
      'npm run dev',
      'npm install',
      'codex',
      'claude',
      'cat README.md',
      'tail -f app.log',
      'systemctl status nginx',
      'echo "rm is a word in this sentence"',
      'grep -r "reboot" ./docs',
      'vim /etc/hosts',
      'mkdir -p build/output',
      'cp -r src dist',
      'python manage.py migrate',
      '',
      '   ',
    ];

    for (final command in safe) {
      test('allows: ${command.trim().isEmpty ? '(blank)' : command}',
          () => expect(flags(command), isFalse));
    }
  });

  group('assessment shape', () {
    test('an empty command produces no signals', () {
      expect(analyzer.analyze('').signals, isEmpty);
    });

    test('collects multiple signals from one command', () {
      final assessment = analyzer.analyze('rm -rf /tmp/x && sudo reboot');
      expect(assessment.signals.length, greaterThanOrEqualTo(2));
    });
  });
}
