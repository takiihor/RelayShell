import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/common.dart';

/// About and privacy (SPEC 34).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } on MissingPluginException {
      // Not available in every host environment; the screen still works.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.terminal,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: theme.textTheme.titleMedium),
                    if (_version != null)
                      Text(
                        l10n.aboutVersion(_version!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.aboutTagline, style: theme.textTheme.bodyMedium),

          const SizedBox(height: 24),
          SectionHeader(
            title: l10n.aboutPrivacyTitle,
            padding: EdgeInsets.zero,
          ),
          Text(
            l10n.aboutPrivacyBody,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: _version,
            ),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(l10n.aboutOpenSource),
          ),
        ],
      ),
    );
  }
}
