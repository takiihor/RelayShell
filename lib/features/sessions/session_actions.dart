import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../core/shell/multiplexer_session.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import '../hosts/host_key_dialog.dart';
import '../terminal/terminal_providers.dart';
import 'session_launcher.dart';

/// Opens a terminal on [host] and navigates to it.
Future<void> openHostTerminal(
  BuildContext context,
  WidgetRef ref,
  Host host, {
  SessionMode? mode,
}) async {
  await _launch(context, ref, () async {
    final session = await ref
        .read(sessionLauncherProvider)
        .openHostTerminal(
          host: host,
          preferences: ref.read(preferencesProvider),
          mode: mode,
        );
    return session.id;
  });
}

/// Opens the mobile-first Conversation Mode over a fresh interactive PTY.
///
/// A normal terminal tab may currently be inside vim/htop/Codex, so reusing it
/// would risk sending the framing protocol into a TUI. The new tab still shares
/// the host's SSH transport and, in persistent mode, gets its own managed
/// multiplexer session. Terminal Mode can then open this exact PTY if needed.
Future<void> openHostConversation(
  BuildContext context,
  WidgetRef ref,
  Host host, {
  SessionMode? mode,
}) async {
  await _launch(
    context,
    ref,
    () async {
      final session = await ref
          .read(sessionLauncherProvider)
          .openAdditionalHostTerminal(
            host: host,
            preferences: ref.read(preferencesProvider),
            mode: mode,
          );
      return session.id;
    },
    destination: Routes.conversation,
  );
}

/// Opens an additional terminal instead of focusing the existing one.
Future<void> openAdditionalHostTerminal(
  BuildContext context,
  WidgetRef ref,
  Host host, {
  SessionMode? mode,
}) async {
  await _launch(context, ref, () async {
    final session = await ref
        .read(sessionLauncherProvider)
        .openAdditionalHostTerminal(
          host: host,
          preferences: ref.read(preferencesProvider),
          mode: mode,
        );
    return session.id;
  });
}

/// Opens [project] at its remote path, optionally running an action.
Future<void> openProjectTerminal(
  BuildContext context,
  WidgetRef ref,
  Project project, {
  SessionMode? mode,
  String? runCommand,
  String? actionLabel,
}) async {
  final host = await ref.read(hostsRepositoryProvider).byId(project.hostId);
  if (host == null) {
    if (context.mounted) {
      showMessage(
        context,
        AppLocalizations.of(context).errorNoHosts,
        isError: true,
      );
    }
    return;
  }

  if (!context.mounted) return;
  await _launch(context, ref, () async {
    final session = await ref
        .read(sessionLauncherProvider)
        .openProject(
          project: project,
          host: host,
          preferences: ref.read(preferencesProvider),
          mode: mode,
          runCommand: runCommand,
          actionLabel: actionLabel,
        );
    return session.id;
  });
}

/// Opens a project directly in Conversation Mode while preserving the project's
/// configured working directory and persistent-session behavior.
Future<void> openProjectConversation(
  BuildContext context,
  WidgetRef ref,
  Project project, {
  SessionMode? mode,
}) async {
  final host = await ref.read(hostsRepositoryProvider).byId(project.hostId);
  if (host == null) {
    if (context.mounted) {
      showMessage(
        context,
        AppLocalizations.of(context).errorNoHosts,
        isError: true,
      );
    }
    return;
  }

  if (!context.mounted) return;
  await _launch(
    context,
    ref,
    () async {
      final session = await ref
          .read(sessionLauncherProvider)
          .openProject(
            project: project,
            host: host,
            preferences: ref.read(preferencesProvider),
            mode: mode,
          );
      return session.id;
    },
    destination: Routes.conversation,
  );
}

/// Resumes a saved session (SPEC 40.4).
Future<void> resumeSessionRecord(
  BuildContext context,
  WidgetRef ref,
  SessionRecord record,
) async {
  await _launch(context, ref, () async {
    final session = await ref
        .read(sessionLauncherProvider)
        .resumeSession(
          record: record,
          preferences: ref.read(preferencesProvider),
        );
    return session.id;
  });
}

/// Runs a prepared command in an interactive terminal (SPEC 13.1).
Future<void> openCommandTerminal(
  BuildContext context,
  WidgetRef ref,
  PreparedCommand prepared,
) async {
  await _launch(context, ref, () async {
    final session = await ref
        .read(sessionLauncherProvider)
        .runInteractive(
          prepared: prepared,
          preferences: ref.read(preferencesProvider),
        );
    return session.id;
  });
}

/// Attaches to a tmux session discovered on the host.
Future<void> attachTmuxSession(
  BuildContext context,
  WidgetRef ref,
  Host host,
  MultiplexerSession session,
) async {
  await _launch(context, ref, () async {
    final terminal = await ref
        .read(sessionLauncherProvider)
        .attachTmuxSession(
          host: host,
          session: session,
          preferences: ref.read(preferencesProvider),
        );
    return terminal.id;
  });
}

/// Runs a launch, showing a blocking progress dialog and mapping failures onto
/// the actionable error surfaces (SPEC 31).
///
/// A changed host key gets its own dialog rather than a snack bar: it is the
/// one failure the user must actually read.
Future<void> _launch(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function() action, {
  String destination = Routes.terminal,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;

  unawaitedShowDialog(context);

  try {
    final sessionId = await action();
    if (dialogOpen && navigator.canPop()) navigator.pop();
    dialogOpen = false;

    if (!context.mounted) return;
    ref.read(terminalManagerProvider).setActive(sessionId);
    context.push('$destination?session=$sessionId');
  } on SshFailure catch (failure) {
    if (dialogOpen && navigator.canPop()) navigator.pop();
    dialogOpen = false;
    if (!context.mounted) return;

    if (failure.kind == SshFailureKind.hostKeyChanged) {
      final parts = (failure.technicalDetail ?? '').split('\n\n');
      await HostKeyChangedDialog.show(
        context,
        hostname: failure.message,
        saved: parts.isNotEmpty ? parts.first.replaceFirst('Saved:\n', '') : '',
        received: parts.length > 1
            ? parts[1].replaceFirst('Received:\n', '')
            : '',
      );
      return;
    }
    showFailure(context, failure);
  } on MultiplexerUnavailableException catch (error) {
    if (dialogOpen && navigator.canPop()) navigator.pop();
    dialogOpen = false;
    if (!context.mounted) return;
    showMessage(
      context,
      AppLocalizations.of(context).sessionsTmuxMissingBody(error.kind.label),
      isError: true,
    );
  } on LaunchException catch (error) {
    if (dialogOpen && navigator.canPop()) navigator.pop();
    dialogOpen = false;
    if (!context.mounted) return;
    showMessage(context, error.message, isError: true);
  } catch (error) {
    if (dialogOpen && navigator.canPop()) navigator.pop();
    if (!context.mounted) return;
    showFailure(context, error);
  }
}

/// Shows the connecting dialog without awaiting it.
///
/// The dialog's future only completes when it is dismissed, so awaiting it
/// would deadlock the launch it is reporting on.
void unawaitedShowDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _ConnectingDialog(),
  );
}

class _ConnectingDialog extends ConsumerWidget {
  const _ConnectingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 20),
          Expanded(child: Text(l10n.statusConnecting)),
        ],
      ),
    );
  }
}
