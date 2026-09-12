import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/terminal/herdr_composer.dart';
import 'package:relayshell/features/terminal/terminal_session.dart';
import 'package:relayshell/l10n/app_localizations.dart';

class _Pane implements TerminalSession {
  @override
  bool get isLive => true;
  @override
  String paneDraft = '';
  final sent = <String>[];
  Completer<void>? pending;
  @override
  Future<void> submitPane(String text) async {
    sent.add(text);
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _Pane pane, {
    Size size = const Size(320, 568),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              HerdrComposer(session: pane),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('multiline send is single flight and preserves a newer draft', (
    tester,
  ) async {
    final pane = _Pane()..pending = Completer<void>();
    await pump(tester, pane);
    await tester.enterText(find.byType(TextField), 'hello\n你好');
    await tester.pump();
    await tester.tap(find.byTooltip('Send to pane'));
    await tester.pump();
    expect(pane.sent, ['hello\n你好']);
    await tester.enterText(find.byType(TextField), 'next draft');
    await tester.tap(find.byTooltip('Send to pane'));
    expect(pane.sent, hasLength(1));
    pane.pending!.complete();
    await tester.pump();
    expect(pane.paneDraft, 'next draft');
  });

  testWidgets(
    'uncertain delivery retains draft and never retries automatically',
    (tester) async {
      final pane = _Pane()..pending = Completer<void>();
      await pump(tester, pane);
      await tester.enterText(find.byType(TextField), 'important prompt');
      await tester.pump();
      await tester.tap(find.byTooltip('Send to pane'));
      await tester.pump();
      pane.pending!.completeError(StateError('connection lost'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(pane.paneDraft, 'important prompt');
      expect(pane.sent, hasLength(1));
    },
  );

  testWidgets('IME composition does not submit unfinished input', (
    tester,
  ) async {
    final pane = _Pane();
    await pump(tester, pane);
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send to pane'));
    expect(pane.sent, isEmpty);
  });

  for (final size in [const Size(320, 568), const Size(667, 320)]) {
    testWidgets('composer fits $size with large text and keyboard', (
      tester,
    ) async {
      await pump(tester, _Pane(), size: size, scale: 2);
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * .4);
      await tester.enterText(find.byType(TextField), 'one\ntwo\nthree');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
