import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/app/app.dart';
import 'package:relayshell/core/bootstrap.dart';
import 'package:relayshell/core/providers.dart';
import 'package:relayshell/core/storage/secret_store.dart';
import 'package:relayshell/l10n/app_localizations.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end widget tests over the real service graph.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late AppServices services;

  Future<AppServices> startServices() => AppServices.start(
    databasePath: inMemoryDatabasePath,
    secretStore: InMemorySecretStore(),
    databaseFactory: databaseFactoryFfiNoIsolate,
    promptForHostKey: (_) async => false,
    promptForSecret: (_) async => null,
    promptForKeyboardInteractive: (_) async => null,
  );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(services)],
        child: const RelayShellApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async => services = await startServices());
  tearDown(() async => services.dispose());

  testWidgets('starts with the conversation-first connection launcher', (
    tester,
  ) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.appTitle), findsWidgets);
    expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
    expect(find.text(l10n.homeAddComputer), findsWidgets);
    expect(find.text(l10n.navProjects), findsNothing);
    expect(find.text(l10n.navSessions), findsNothing);
  });

  testWidgets(
    'new connection form keeps the Tailscale setup essentials visible',
    (tester) async {
      await pumpApp(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.homeAddComputer).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.connectionSetupTitle), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, l10n.computerFieldHostname),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, l10n.computerFieldUsername),
        findsOneWidget,
      );
      expect(find.text(l10n.computerFieldPort), findsNothing);
    },
  );

  testWidgets('adding a computer returns to the conversation launcher', (
    tester,
  ) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.homeAddComputer).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldName),
      'Europa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldHostname),
      '100.94.210.28',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldUsername),
      'europa',
    );

    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.homeConversationTitle), findsOneWidget);
    expect(find.text('Europa'), findsOneWidget);
    expect(find.text(l10n.conversationOpen), findsOneWidget);
    expect(find.text(l10n.herdrPanes), findsOneWidget);
    expect(find.text(l10n.navProjects), findsNothing);
    expect(find.text(l10n.navSessions), findsNothing);
    final hosts = await services.hosts.all();
    expect(hosts.single.hostname, '100.94.210.28');
    expect(hosts.single.username, 'europa');
  });

  testWidgets('host setup refuses to save without an address and username', (
    tester,
  ) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.homeAddComputer).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.errorRequired), findsWidgets);
    expect(await services.hosts.all(), isEmpty);
  });

  testWidgets('settings remain available without a dashboard tab', (
    tester,
  ) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsAppearance), findsWidgets);

    await tester.tap(find.text(l10n.settingsThemeSystem));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsThemeDark).last);
    await tester.pumpAndSettle();

    final preferences = await services.preferencesRepository.load();
    expect(preferences.themeMode, AppThemeMode.dark);
  });
}
