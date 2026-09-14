import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:relayshell/core/providers.dart';
import 'package:relayshell/features/conversation_shell/conversation_shell_screen.dart';
import 'package:relayshell/features/terminal/terminal_input_modifiers.dart';
import 'package:relayshell/features/terminal/terminal_manager.dart';
import 'package:relayshell/features/terminal/terminal_providers.dart';
import 'package:relayshell/features/terminal/terminal_session.dart';
import 'package:relayshell/l10n/app_localizations.dart';
import 'package:relayshell/shared/models/models.dart';

class _Preferences extends PreferencesController {
  @override
  AppPreferences build() => const AppPreferences();
}

class _Session extends ChangeNotifier implements TerminalSession {
  _Session({this.pane = false});
  final bool pane;
  final raw = <String>[];
  @override
  String paneDraft = '';
  @override
  AppPreferences get preferences => const AppPreferences();
  @override
  bool get canReconnect => false;
  @override
  Future<void> submitPane(String text) async {
    sent.add(text);
  }

  @override
  void sendRaw(String text) => raw.add(text);
  @override
  void scrollHerdr(bool up) {}
  final sent = <String>[];
  final output = StreamController<String>.broadcast(sync: true);
  @override
  final terminal = Terminal();
  @override
  final controller = TerminalController();
  @override
  final inputModifiers = TerminalInputModifiers();
  @override
  String get id => 'test';
  @override
  bool get isLive => true;
  @override
  bool get isHerdrPane => pane;
  @override
  String get title => 'Remote PC';
  @override
  String get subtitle => 'Test shell';
  @override
  Host get host => Host(
    id: 'h',
    name: title,
    hostname: 'localhost',
    port: 22,
    username: 'dev',
    authMethod: AuthMethod.privateKey,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  @override
  Stream<String> get outputStream => output.stream;
  @override
  void sendText(String text, {bool submit = true}) => sent.add(text);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void dispose() {
    output.close();
    controller.dispose();
    inputModifiers.dispose();
    super.dispose();
  }
}

class _Manager extends ChangeNotifier implements TerminalManager {
  _Manager(this.session);
  final _Session session;
  @override
  TerminalSession? byId(String id) => session;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('entering herdr opens pane selection without launching its TUI', (
    tester,
  ) async {
    final session = _Session();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWith(_Preferences.new),
          terminalManagerProvider.overrideWith((ref) => _Manager(session)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ConversationShellScreen(sessionId: 'test'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'herdr');
    await tester.tap(find.byTooltip('Run'));
    await tester.pumpAndSettle();
    expect(
      session.sent,
      isEmpty,
      reason: 'Herdr should open the native pane picker, not a nested terminal',
    );
    expect(find.byType(TerminalView), findsNothing);
    expect(find.text('Herdr panes'), findsOneWidget);
  });
  for (final size in [const Size(375, 667), const Size(667, 375)]) {
    testWidgets(
      'pane stays conversational and accepts text/navigation at $size',
      (tester) async {
        final session = _Session(pane: true);
        addTearDown(session.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesProvider.overrideWith(_Preferences.new),
              terminalManagerProvider.overrideWith((ref) => _Manager(session)),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ConversationShellScreen(sessionId: 'test'),
            ),
          ),
        );
        session.terminal.write(
          'Working 10%\r\x1b[2KReady for input${' ' * 50}\r\n  second line',
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump();
        expect(find.byType(TerminalView), findsNothing);
        if (size.height > 400) {
          expect(find.text('Ready for input\n  second line'), findsOneWidget);
        }
        await tester.enterText(find.byType(TextField), 'hello pane');
        await tester.pump();
        await tester.tap(find.byTooltip('Send to pane'));
        await tester.pump();
        expect(session.sent, ['hello pane']);
        expect(session.paneDraft, isEmpty);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(size.height - 160),
        );
        await tester.tap(find.text('TAB'));
        expect(session.raw, ['\t']);
        await tester.ensureVisible(find.text('Enter'));
        await tester.pump();
        await tester.tap(find.text('Enter'));
        expect(session.raw, ['\t', '\r']);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
