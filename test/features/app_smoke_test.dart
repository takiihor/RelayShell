import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/app/app.dart';
import 'package:relayshell/core/providers.dart';
import 'package:relayshell/core/bootstrap.dart';
import 'package:relayshell/core/storage/secret_store.dart';
import 'package:relayshell/l10n/app_localizations.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end widget tests over the real service graph.
///
/// The database is in-memory and secrets go to [InMemorySecretStore], but every
/// other layer — repositories, providers, router, screens — is the production
/// one, so these catch wiring mistakes that unit tests cannot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  // The no-isolate factory is essential here: `pumpAndSettle` drives a
  // fake-async zone, which cannot advance work happening on sqflite's default
  // background isolate, so every database read would hang forever.
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

  testWidgets('starts on Home with the first-run empty state', (tester) async {
    await pumpApp(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.appTitle), findsWidgets);
    expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
    expect(find.text(l10n.homeAddComputer), findsOneWidget);
  });

  testWidgets('every primary tab opens', (tester) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    for (final (destination, expectedTitle) in [
      (l10n.navComputers, l10n.computersEmptyTitle),
      (l10n.navProjects, l10n.projectsEmptyTitle),
      (l10n.navSessions, l10n.sessionsEmptyTitle),
      (l10n.navMore, l10n.moreCommands),
    ]) {
      await tester.tap(find.text(destination).last);
      await tester.pumpAndSettle();
      expect(
        find.text(expectedTitle),
        findsWidgets,
        reason: 'tab "$destination" did not show "$expectedTitle"',
      );
    }
  });

  testWidgets('More opens each secondary section', (tester) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.navMore).last);
    await tester.pumpAndSettle();

    for (final (entry, expected) in [
      (l10n.moreCommands, l10n.commandsEmptyTitle),
      (l10n.moreKeys, l10n.keysEmptyTitle),
      (l10n.moreForwarding, l10n.forwardingEmptyTitle),
      (l10n.moreSettings, l10n.settingsAppearance),
      (l10n.moreAbout, l10n.aboutPrivacyTitle),
    ]) {
      await tester.tap(find.text(entry).last);
      await tester.pumpAndSettle();
      expect(find.text(expected), findsWidgets, reason: 'section "$entry"');

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('adding a computer makes it appear on Home', (tester) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.homeAddComputer));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldName),
      'Home PC',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldHostname),
      '10.0.0.5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldUsername),
      'dev',
    );

    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    // Landed on the host detail screen.
    expect(find.text('Home PC'), findsWidgets);
    expect(find.text('dev@10.0.0.5'), findsWidgets);

    // And it is persisted.
    final hosts = await services.hosts.all();
    expect(hosts, hasLength(1));
    expect(hosts.single.name, 'Home PC');
  });

  testWidgets('the host form refuses to save without required fields', (
    tester,
  ) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.homeAddComputer));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.errorRequired), findsWidgets);
    expect(await services.hosts.all(), isEmpty);
  });

  testWidgets('the host form rejects an out-of-range port', (tester) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.homeAddComputer));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.computerFieldPort),
      '99999',
    );
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.errorInvalidPort), findsOneWidget);
  });

  testWidgets('a saved command appears in the commands list', (tester) async {
    final now = DateTime.now();
    await services.commands.upsert(
      SavedCommand(
        id: 'c1',
        name: 'Disk Usage',
        command: 'df -h',
        scope: CommandScope.global,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.navMore).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.moreCommands).last);
    await tester.pumpAndSettle();

    expect(find.text('Disk Usage'), findsOneWidget);
    expect(find.text('df -h'), findsOneWidget);
  });

  testWidgets('a favourited command shows as a Home quick action', (
    tester,
  ) async {
    final now = DateTime.now();
    await services.commands.upsert(
      SavedCommand(
        id: 'c1',
        name: 'Git Status',
        command: 'git status',
        scope: CommandScope.global,
        favorite: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await services.hosts.upsert(
      Host(
        id: 'h1',
        name: 'Home PC',
        hostname: '10.0.0.5',
        port: 22,
        username: 'dev',
        authMethod: AuthMethod.privateKey,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.homeQuickActionsTitle), findsOneWidget);
    expect(find.text('Git Status'), findsOneWidget);
  });

  testWidgets('changing the theme setting takes effect immediately', (
    tester,
  ) async {
    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.navMore).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.moreSettings).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.settingsThemeSystem));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsThemeDark).last);
    await tester.pumpAndSettle();

    final preferences = await services.preferencesRepository.load();
    expect(preferences.themeMode, AppThemeMode.dark);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('search finds a saved computer', (tester) async {
    final now = DateTime.now();
    await services.hosts.upsert(
      Host(
        id: 'h1',
        name: 'Production VPS',
        hostname: 'vps.example.com',
        port: 22,
        username: 'root',
        authMethod: AuthMethod.privateKey,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await pumpApp(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Production');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text(l10n.searchSectionComputers), findsOneWidget);
    expect(find.text('Production VPS'), findsOneWidget);
  });
}
