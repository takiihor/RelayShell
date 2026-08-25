import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../theme/status_colors.dart';

/// A small labelled status marker (SPEC 39).
///
/// Always renders a label beside the colour. Status carried by colour alone
/// fails for colour-blind users and in bright sunlight, both of which are
/// ordinary conditions for a phone (SPEC 37).
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.status,
    required this.label,
    super.key,
    this.compact = false,
  });

  final SemanticStatus status;
  final String label;

  /// Renders just the dot and a tooltip, for dense rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.forStatus(status);
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (compact) {
      return Tooltip(
        message: label,
        child: Semantics(label: label, child: dot),
      );
    }

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps connection state onto the semantic palette and a localised label.
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({
    required this.state,
    super.key,
    this.compact = false,
  });

  final SshConnectionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (status, label) = switch (state) {
      SshConnectionState.connected => (
        SemanticStatus.connected,
        l10n.statusConnected,
      ),
      SshConnectionState.idle => (SemanticStatus.inactive, l10n.statusIdle),
      SshConnectionState.closed => (
        SemanticStatus.inactive,
        l10n.statusDisconnected,
      ),
      SshConnectionState.failed => (SemanticStatus.error, l10n.statusFailed),
      SshConnectionState.resolving => (
        SemanticStatus.connecting,
        l10n.statusResolving,
      ),
      SshConnectionState.connecting => (
        SemanticStatus.connecting,
        l10n.statusConnecting,
      ),
      SshConnectionState.handshaking => (
        SemanticStatus.connecting,
        l10n.statusHandshaking,
      ),
      SshConnectionState.verifyingHost => (
        SemanticStatus.warning,
        l10n.statusVerifyingHost,
      ),
      SshConnectionState.authenticating => (
        SemanticStatus.connecting,
        l10n.statusAuthenticating,
      ),
      SshConnectionState.reconnecting => (
        SemanticStatus.warning,
        l10n.statusReconnecting,
      ),
    };

    return StatusIndicator(status: status, label: label, compact: compact);
  }
}

/// Advisory host reachability (SPEC 7.2).
class ReachabilityIndicator extends StatelessWidget {
  const ReachabilityIndicator({
    required this.reachability,
    super.key,
    this.compact = false,
  });

  final HostReachability reachability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (status, label) = switch (reachability) {
      HostReachability.unknown => (SemanticStatus.inactive, l10n.statusUnknown),
      HostReachability.checking => (
        SemanticStatus.connecting,
        l10n.statusChecking,
      ),
      HostReachability.reachable => (
        SemanticStatus.connected,
        l10n.statusReachable,
      ),
      HostReachability.unreachable => (
        SemanticStatus.warning,
        l10n.statusUnreachable,
      ),
    };

    return StatusIndicator(status: status, label: label, compact: compact);
  }
}
