import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/bootstrap.dart';
import 'package:relayshell/core/storage/secret_store.dart';
import 'package:relayshell/features/conversation_shell/conversation_controller.dart';
import 'package:relayshell/features/conversation_shell/conversation_session.dart';
import 'package:relayshell/features/conversation_shell/conversation_view.dart';
import 'package:relayshell/features/terminal/terminal_session.dart';
import 'package:relayshell/l10n/app_localizations.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:relayshell/shared/theme/status_colors.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppServices services;
  late _LiveSession session;
  late ConversationSession shell;
  late List<String> sent;

  setUp(() async {
    services = await AppServices.start(
      databasePath: inMemoryDatabasePath,
      databaseFactory: databaseFactoryFfiNoIsolate,
      secretStore: InMemorySecretStore(),
      promptForHostKey: (_) async => false,
      promptForSecret: (_) async => null,
      promptForKeyboardInteractive: (_) async => null,
    );
    shell = ConversationSession(nonce: 'widget');
    sent = [];
    shell.send = sent.add;
    final now = DateTime.now();
    session = _LiveSession(
      id: 'shell',
      host: Host(
        id: 'host',
        name: 'Computer',
        hostname: 'localhost',
        port: 22,
        username: 'dev',
        authMethod: AuthMethod.privateKey,
        createdAt: now,
        updatedAt: now,
      ),
      launchPlan: shell.launchPlan(),
      preferences: const AppPreferences(),
      connections: services.connections,
      conversation: shell,
    );
  });
  tearDown(() async {
    session.dispose();
    await services.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(375, 667),
    double scale = 1,
    double keyboard = 0,
    bool dark = false,
    VoidCallback? onTerminal,
    VoidCallback? onHerdr,
  }) async {
    if (!shell.ready && shell.commands.isEmpty) {
      shell.addOutput('\x1b]777;RS:widget:E:0:0\x07');
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Computer')),
          body: ConversationView(
            session: session,
            onTerminal: onTerminal ?? () {},
            onHerdr: onHerdr,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets(
    'legacy conversation opens Herdr picker without launching a TUI',
    (tester) async {
      var picked = false;
      await pump(tester, onHerdr: () => picked = true);
      await tester.enterText(find.byType(TextField), 'herdr');
      await tester.pump();
      await tester.tap(find.byTooltip('Run'));
      expect(picked, isTrue);
      expect(sent, isEmpty);
    },
  );

  testWidgets('send, draft while running, history and restore draft', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'echo first\necho second');
    await tester.pump();
    await tester.tap(find.byTooltip('Run'));
    await tester.pump();
    expect(sent, hasLength(1));
    await tester.enterText(find.byType(TextField), 'next draft');
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Send input',
            ),
          )
          .onPressed,
      isNotNull,
    );
    shell.addOutput(
      '\x1b]777;RS:widget:B:1\x07first\nsecond\n\x1b]777;RS:widget:E:1:0\x07',
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('first\nsecond\n'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous command'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'echo first\necho second',
    );
    await tester.tap(find.byTooltip('Next command or draft'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'next draft',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'IME composition is not submitted; Ctrl+Enter runs committed input',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '你好',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Run'));
      expect(sent, isEmpty);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'echo 你好',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(sent, hasLength(1));
      expect(shell.active!.command, 'echo 你好');
    },
  );

  testWidgets('terminal handoff keeps command and composer draft', (
    tester,
  ) async {
    var opened = false;
    shell.addOutput('\x1b]777;RS:widget:E:0:0\x07');
    shell.submit('vim');
    await pump(tester, onTerminal: () => opened = true);
    await tester.enterText(find.byType(TextField), 'keep my draft');
    await tester.tap(find.byTooltip('Terminal'));
    await tester.pump();
    expect(opened, isTrue);
    expect(sent, hasLength(1));
    expect(shell.active!.command, 'vim');
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'keep my draft',
    );
  });

  test('short prompts stream immediately and redraws replace old text', () {
    final controller = ConversationController(session: session);
    addTearDown(controller.dispose);
    controller.submit('herdr');
    final token = RegExp(r'RELAYSHELL_BEGIN:([^\\]+)')
        .firstMatch(session.sentTexts.last)![1]!;
    controller.addOutputForTesting('\x1eRELAYSHELL_BEGIN:$token\x1f\n');
    controller.addOutputForTesting('Ready> ');
    expect(controller.activeCommand!.output, 'Ready> ');
    controller.addOutputForTesting('\r\x1b[2KWorking 10%');
    controller.addOutputForTesting('\r\x1b[2KWorking 100%');
    expect(controller.activeCommand!.output, 'Working 100%');
    controller.addOutputForTesting('\x1b[?10');
    controller.addOutputForTesting('49h');
    expect(controller.activeCommand!.fullScreenDetected, isTrue);
  });

  testWidgets('Herdr input remains available while the process runs', (
    tester,
  ) async {
    await pump(tester);
    shell.submit('herdr');
    shell.addOutput('\x1b]777;RS:widget:B:1\x07');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(find.byType(TextField), 'hello agent');
    await tester.pump();
    await tester.tap(find.byTooltip('Send input'));
    expect(sent.last, 'hello agent\r');
    expect(shell.active!.command, 'herdr');
    expect(shell.commands, hasLength(1));
  });

  test('interactive composer uses bracketed paste and a real Enter key', () {
    final controller = ConversationController(session: session);
    addTearDown(controller.dispose);
    controller.submit('herdr');
    session.terminal.write('\x1b[?2004h');
    controller.sendProcessInput('first line\nsecond line');
    expect(
      session.rawInputs.single,
      '\x1b[200~first line\nsecond line\x1b[201~\r',
    );
    expect(controller.commands, hasLength(1));
  });

  test('completes one remote directory for a cd composer draft', () async {
    final controller = ConversationController(session: session);
    final completion = controller.completeDirectory('cd deve');

    expect(session.sentTexts, hasLength(1));
    final marker = RegExp(r'RS:([0-9a-f]+):C:([0-9]+):')
        .firstMatch(session.sentTexts.single)!;
    controller.addOutputForTesting(
      '\x1b]777;RS:${marker[1]}:C:${marker[2]}:'
      '${base64Encode(utf8.encode('development/'))}\x07',
    );

    expect(await completion, 'cd development/');
    controller.dispose();
  });

  testWidgets('running card exposes Stop and Terminal and announces state', (
    tester,
  ) async {
    var opened = false;
    void onTerminal() => opened = true;
    await pump(tester, onTerminal: onTerminal);
    expect(shell.submit('sleep 30'), isTrue);
    await pump(tester, onTerminal: onTerminal);

    // The status row is a live region while running so a screen reader
    // hears the transition, and is coloured like other connecting states.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.liveRegion == true &&
            (w.properties.label ?? '').startsWith('Running'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.textContaining('Running \u00b7')).style?.color,
      StatusColors.of(Brightness.light).connecting,
    );

    // Stop is exposed on the card itself, not only in the status row.
    final stop = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Stop'),
    );
    expect(stop.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(TextButton, 'Stop'));
    await tester.pump();
    expect(sent.any((x) => x == '\x03'), isTrue, reason: 'Stop sends Ctrl+C');

    await tester.tap(find.widgetWithText(TextButton, 'Terminal'));
    await tester.pump();
    expect(opened, isTrue, reason: 'Terminal hands off to the live session');

    shell.addOutput('\x1b]777;RS:widget:B:1\x07');
    shell.addOutput('\x1b]777;RS:widget:E:1:130\x07');
    await pump(tester, onTerminal: onTerminal);
    expect(shell.commands.single.state, ConversationCommandState.interrupted);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.liveRegion == true &&
            (w.properties.label ?? '').startsWith('Running'),
      ),
      findsNothing,
    );
  });

  testWidgets('failed exit is coloured as a result, not an app error', (
    tester,
  ) async {
    await pump(tester);
    expect(shell.submit('false'), isTrue);
    shell.addOutput('\x1b]777;RS:widget:B:1\x07');
    shell.addOutput('\x1b]777;RS:widget:E:1:3\x07');
    await pump(tester);
    expect(
      tester.widget<Text>(find.textContaining('Exit 3 \u00b7')).style?.color,
      StatusColors.of(Brightness.light).error,
    );
  });

  test('conversation subtitle anchors the launch directory', () {
    // Own ConversationSession rather than the shared one: disposing a
    // session cascades into it, and the shared one must survive tearDown.
    final local = ConversationSession(nonce: 'subtitle');
    final withDirectory = _LiveSession(
      id: 'shell-directory',
      host: session.host,
      launchPlan: local.launchPlan(workingDirectory: '/home/dev/hk_live'),
      preferences: const AppPreferences(),
      connections: services.connections,
      conversation: local,
    );
    expect(withDirectory.subtitle, contains('/home/dev/hk_live'));

    final withoutDirectory = _LiveSession(
      id: 'shell-plain',
      host: session.host,
      launchPlan: local.launchPlan(),
      preferences: const AppPreferences(),
      connections: services.connections,
      conversation: null,
    );
    expect(withoutDirectory.subtitle, contains('shell'));
    expect(withoutDirectory.subtitle, isNot(contains('/home/dev/hk_live')));
    withDirectory.dispose();
    withoutDirectory.dispose();
  });

  for (final (size, scale, keyboard) in [
    (const Size(375, 667), 1.0, 280.0),
    (const Size(667, 375), 1.0, 160.0),
    (const Size(375, 667), 3.0, 280.0),
    (const Size(1024, 768), 2.0, 0.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('usable at $size text $scale keyboard $keyboard dark $dark', (
        tester,
      ) async {
        shell.addOutput('\x1b]777;RS:widget:E:0:0\x07');
        shell.submit('sleep 30');
        await pump(
          tester,
          size: size,
          scale: scale,
          keyboard: keyboard,
          dark: dark,
        );
        await tester.enterText(
          find.byType(TextField),
          'a draft\nwith multiple\nlines',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final field = tester.getRect(find.byType(TextField));
        expect(field.bottom, lessThanOrEqualTo(size.height - keyboard));
        expect(
          tester.getSize(find.byTooltip('Send input')).width,
          greaterThanOrEqualTo(48),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _LiveSession extends TerminalSession {
  _LiveSession({
    required super.id,
    required super.host,
    required super.launchPlan,
    required super.preferences,
    required super.connections,
    required super.conversation,
  });

  final List<String> sentTexts = [];
  final List<String> rawInputs = [];

  @override
  void sendRaw(String sequence) => rawInputs.add(sequence);

  @override
  void sendText(String text, {bool submit = true}) => sentTexts.add(text);

  @override
  bool get isLive => true;
}
