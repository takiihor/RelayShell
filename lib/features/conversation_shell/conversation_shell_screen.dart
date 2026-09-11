import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/navigation/routes.dart';
import '../terminal/terminal_providers.dart';
import '../terminal/terminal_session.dart';
import 'conversation_controller.dart';
import 'conversation_models.dart';

/// Mobile-first command/output view over an existing live terminal PTY.
class ConversationShellScreen extends ConsumerStatefulWidget {
  const ConversationShellScreen({required this.sessionId, super.key});

  final String? sessionId;

  @override
  ConsumerState<ConversationShellScreen> createState() =>
      _ConversationShellScreenState();
}

class _ConversationShellScreenState
    extends ConsumerState<ConversationShellScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ConversationController? _conversation;
  TerminalSession? _session;

  @override
  void initState() {
    super.initState();
    _bindSession();
  }

  void _bindSession() {
    final manager = ref.read(terminalManagerProvider);
    final session = widget.sessionId == null
        ? manager.active
        : manager.byId(widget.sessionId!);
    _session = session;
    if (session == null) return;
    _conversation = ConversationController(session: session)
      ..addListener(_onConversationChanged);
  }

  void _onConversationChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _conversation?.removeListener(_onConversationChanged);
    _conversation?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    final conversation = _conversation;

    if (session == null || conversation == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Icon(Icons.terminal_outlined, size: 40)),
      );
    }

    if (!conversation.supportsConversation) {
      return Scaffold(
        appBar: AppBar(title: Text(session.title)),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => _openTerminal(session),
            icon: const Icon(Icons.terminal),
            label: Text(l10n.computerOpenTerminal),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title),
            Text(
              session.subtitle,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openTerminal(session),
            icon: const Icon(Icons.terminal),
            tooltip: l10n.computerOpenTerminal,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: conversation.commands.isEmpty
                ? Center(
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 42,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: conversation.commands.length,
                    itemBuilder: (context, index) => _CommandExchange(
                      command: conversation.commands[index],
                      onStop: conversation.interrupt,
                      onOpenTerminal: () => _openTerminal(session),
                    ),
                  ),
          ),
          _Composer(
            controller: _input,
            enabled: conversation.canSubmit,
            running: conversation.activeCommand != null,
            onSubmit: _submit,
            onStop: conversation.interrupt,
          ),
        ],
      ),
    );
  }

  void _submit() {
    final conversation = _conversation;
    if (conversation == null || !conversation.canSubmit) return;
    final text = _input.text;
    if (text.trim().isEmpty) return;
    conversation.submit(text);
    _input.clear();
  }

  void _openTerminal(TerminalSession session) {
    ref.read(terminalManagerProvider).setActive(session.id);
    context.push('${Routes.terminal}?session=${session.id}');
  }
}

class _CommandExchange extends StatelessWidget {
  const _CommandExchange({
    required this.command,
    required this.onStop,
    required this.onOpenTerminal,
  });

  final ConversationCommand command;
  final VoidCallback onStop;
  final VoidCallback onOpenTerminal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final duration = command.duration;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SelectableText(
                command.command,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (command.output.isNotEmpty)
                  SelectableText(
                    command.output.trimRight(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                if (command.isRunning) ...[
                  if (command.output.isNotEmpty) const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onStop,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: Text(l10n.actionStop),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: onOpenTerminal,
                        icon: const Icon(Icons.terminal, size: 18),
                        label: Text(l10n.computerOpenTerminal),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (command.exitCode != null)
                        Text(
                          l10n.commandExitCode(command.exitCode!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: command.exitCode == 0
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                        ),
                      if (duration != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(duration),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onOpenTerminal,
                        icon: const Icon(Icons.terminal, size: 18),
                        tooltip: l10n.computerOpenTerminal,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inSeconds < 1) return '${duration.inMilliseconds} ms';
    if (duration.inMinutes < 1) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes min $seconds s';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.running,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool running;
  final VoidCallback onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottom > 0 ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: l10n.computerRunCommand,
                    prefixText: r'$ ',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: running ? onStop : enabled ? onSubmit : null,
                icon: Icon(running ? Icons.stop : Icons.arrow_upward),
                tooltip: running ? l10n.actionStop : l10n.actionRun,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
