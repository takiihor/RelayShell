// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RelayShell';

  @override
  String get appShortTitle => 'RelayShell';

  @override
  String get navHome => 'Home';

  @override
  String get navComputers => 'Computers';

  @override
  String get navProjects => 'Projects';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navMore => 'More';

  @override
  String get moreCommands => 'Commands';

  @override
  String get moreKeys => 'Keys';

  @override
  String get moreForwarding => 'Port Forwarding';

  @override
  String get moreSettings => 'Settings';

  @override
  String get moreAbout => 'About';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDuplicate => 'Duplicate';

  @override
  String get actionClose => 'Close';

  @override
  String get actionRetry => 'Try Again';

  @override
  String get actionConnect => 'Connect';

  @override
  String get actionDisconnect => 'Disconnect';

  @override
  String get actionReconnect => 'Reconnect';

  @override
  String get actionResume => 'Resume';

  @override
  String get actionRun => 'Run';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionRename => 'Rename';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopyPath => 'Copy Path';

  @override
  String get actionShare => 'Share';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionDone => 'Done';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionTrust => 'Trust';

  @override
  String get actionBlock => 'Block';

  @override
  String get actionUnlock => 'Unlock';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionTest => 'Test Connection';

  @override
  String get actionWake => 'Wake';

  @override
  String get actionStart => 'Start';

  @override
  String get actionStop => 'Stop';

  @override
  String get actionImport => 'Import';

  @override
  String get actionExport => 'Export';

  @override
  String get actionGenerate => 'Generate';

  @override
  String get actionUpload => 'Upload';

  @override
  String get actionDownload => 'Download';

  @override
  String get actionNewFolder => 'New Folder';

  @override
  String get actionSelectAll => 'Select All';

  @override
  String get actionShowDetails => 'Technical details';

  @override
  String get homeContinueTitle => 'Continue';

  @override
  String get homeComputersTitle => 'Computers';

  @override
  String get homeProjectsTitle => 'Projects';

  @override
  String get homeQuickActionsTitle => 'Quick Actions';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeEmptyTitle => 'Welcome';

  @override
  String get homeEmptyBody =>
      'Add a computer you can reach over SSH to get started.';

  @override
  String get homeAddComputer => 'Add Computer';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get statusChecking => 'Checking';

  @override
  String get statusReachable => 'Reachable';

  @override
  String get statusUnreachable => 'Unreachable';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusResolving => 'Looking up address';

  @override
  String get statusHandshaking => 'Negotiating';

  @override
  String get statusVerifyingHost => 'Verifying identity';

  @override
  String get statusAuthenticating => 'Signing in';

  @override
  String get statusReconnecting => 'Reconnecting';

  @override
  String get statusFailed => 'Failed';

  @override
  String get computersTitle => 'Computers';

  @override
  String get computersEmptyTitle => 'No computers yet';

  @override
  String get computersEmptyBody =>
      'Add a computer that you can access through SSH.';

  @override
  String get computersAdd => 'Add Computer';

  @override
  String get computerNew => 'New Computer';

  @override
  String get computerEdit => 'Edit Computer';

  @override
  String get computerFieldName => 'Name';

  @override
  String get computerFieldNameHint => 'Home PC';

  @override
  String get computerFieldHostname => 'Hostname or IP';

  @override
  String get computerFieldHostnameHint => '192.168.1.10 or server.example.com';

  @override
  String get computerFieldPort => 'Port';

  @override
  String get computerFieldUsername => 'Username';

  @override
  String get computerFieldStartupDirectory => 'Startup directory';

  @override
  String get computerFieldStartupDirectoryHelp =>
      'Optional. Terminals open here.';

  @override
  String get computerFieldNotes => 'Notes';

  @override
  String get computerFieldNotesHelp => 'Optional. Only you can see these.';

  @override
  String get computerFieldPlatform => 'Remote shell';

  @override
  String get computerFieldPlatformHelp =>
      'Determines how paths are quoted and whether tmux is offered.';

  @override
  String get computerFieldColor => 'Colour';

  @override
  String get computerSectionConnection => 'Connection';

  @override
  String get computerSectionAuthentication => 'Authentication';

  @override
  String get computerSectionOptions => 'Options';

  @override
  String get computerSectionWol => 'Wake-on-LAN';

  @override
  String get computerFavorite => 'Pin to Home';

  @override
  String get computerDeleteTitle => 'Delete this computer?';

  @override
  String get computerDeleteBody =>
      'Its projects, commands, saved sessions and forwards will be deleted too. Nothing on the remote machine changes.';

  @override
  String get computerDuplicateSuffix => 'copy';

  @override
  String get computerNoCredential => 'No credential selected';

  @override
  String get computerOpenTerminal => 'Open Terminal';

  @override
  String get computerNewTerminal => 'New Terminal';

  @override
  String get computerResumeSession => 'Resume Session';

  @override
  String get computerFiles => 'Files';

  @override
  String get computerProjects => 'Projects';

  @override
  String get computerRunCommand => 'Run Command';

  @override
  String get computerForwarding => 'Port Forwarding';

  @override
  String computerLastConnected(String when) {
    return 'Last connected $when';
  }

  @override
  String get computerNeverConnected => 'Never connected';

  @override
  String get authMethodPrivateKey => 'SSH private key';

  @override
  String get authMethodPassword => 'Password';

  @override
  String get authMethodKeyboardInteractive => 'Keyboard-interactive';

  @override
  String get authMethodAgent => 'SSH agent';

  @override
  String get authMethodRecommendation => 'Key authentication is recommended.';

  @override
  String get authSelectCredential => 'Credential';

  @override
  String get authNoKeysYet => 'No keys yet';

  @override
  String get authAddKey => 'Add a key';

  @override
  String get authSavePassword => 'Save password';

  @override
  String get authSavePasswordHelp =>
      'Stored in this device\'s secure storage. Leave off to be asked each time.';

  @override
  String get authAgentUnavailable =>
      'SSH agent authentication is not available on this device.';

  @override
  String get testConnectionTitle => 'Test Connection';

  @override
  String get testConnectionRunning => 'Connecting…';

  @override
  String get testConnectionSuccess => 'Connected successfully.';

  @override
  String get testConnectionOptional =>
      'Optional. You can save without testing.';

  @override
  String get hostKeyTitle => 'Verify this computer';

  @override
  String hostKeyBody(String hostname) {
    return 'This is the first time you have connected to $hostname. Check the fingerprint matches the one on the computer before trusting it.';
  }

  @override
  String get hostKeyType => 'Key type';

  @override
  String get hostKeyFingerprint => 'SHA-256 fingerprint';

  @override
  String hostKeyHint(String type) {
    return 'On the computer, run: ssh-keygen -lf /etc/ssh/ssh_host_${type}_key.pub';
  }

  @override
  String get hostKeyChangedTitle => 'Warning: identity changed';

  @override
  String get hostKeyChangedBody =>
      'The SSH identity of this computer has changed. This can mean the server was rebuilt — or that something is intercepting the connection.';

  @override
  String get hostKeyChangedSaved => 'Saved';

  @override
  String get hostKeyChangedReceived => 'Received';

  @override
  String get hostKeyChangedBlocked => 'The connection has been blocked.';

  @override
  String get hostKeyForget => 'Forget saved key';

  @override
  String hostKeyForgetConfirm(String hostname) {
    return 'Forget the saved key for $hostname? The next connection will ask you to verify it again.';
  }

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsEmptyTitle => 'No projects yet';

  @override
  String get projectsEmptyBody =>
      'A project links a remote folder with terminal sessions and reusable actions.';

  @override
  String get projectsAdd => 'Add Project';

  @override
  String get projectNew => 'New Project';

  @override
  String get projectEdit => 'Edit Project';

  @override
  String get projectFieldName => 'Name';

  @override
  String get projectFieldHost => 'Computer';

  @override
  String get projectFieldPath => 'Remote path';

  @override
  String get projectFieldPathHint => '~/projects/my-app';

  @override
  String get projectFieldDescription => 'Description';

  @override
  String get projectFieldSessionMode => 'Default session';

  @override
  String get projectFieldTmuxName => 'tmux session name';

  @override
  String get projectFieldTmuxNameHelp =>
      'Leave empty to generate one automatically.';

  @override
  String get projectFavorite => 'Pin to Home';

  @override
  String get projectActionsTitle => 'Actions';

  @override
  String get projectFilesTitle => 'Files';

  @override
  String get projectBrowseFiles => 'Browse Project';

  @override
  String get projectOpenTerminal => 'Open Terminal';

  @override
  String get projectNoActions => 'No actions yet';

  @override
  String get projectNoActionsBody =>
      'Add a command to run it here with one tap.';

  @override
  String get projectAddAction => 'Add Action';

  @override
  String get projectDeleteTitle => 'Delete this project?';

  @override
  String get projectDeleteBody =>
      'Its commands and saved sessions will be deleted too. The remote folder is not touched.';

  @override
  String projectLastOpened(String when) {
    return 'Opened $when';
  }

  @override
  String get sessionModeDirect => 'Direct';

  @override
  String get sessionModePersistent => 'Persistent';

  @override
  String sessionModePersistentNamed(String name) {
    return 'Persistent ($name)';
  }

  @override
  String get sessionModeDirectHelp =>
      'A normal SSH shell. It ends if the connection drops.';

  @override
  String get sessionModePersistentHelp =>
      'Runs inside tmux on the computer, so work survives a dropped connection.';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsEmptyTitle => 'No sessions yet';

  @override
  String get sessionsEmptyBody =>
      'Open a terminal or start a persistent session and it will appear here.';

  @override
  String get sessionsLive => 'Running now';

  @override
  String get sessionsOpenTabs => 'Open tabs';

  @override
  String get terminalStateConnecting => 'Connecting';

  @override
  String get terminalStateConnected => 'Connected';

  @override
  String get terminalStateDisconnected => 'Disconnected';

  @override
  String get terminalStateEnded => 'Ended';

  @override
  String get terminalStateFailed => 'Failed';

  @override
  String get sessionsSaved => 'Saved';

  @override
  String sessionsOnHost(String host) {
    return 'On $host';
  }

  @override
  String get sessionsRefresh => 'Check computer';

  @override
  String get sessionsKillTitle => 'End this session?';

  @override
  String sessionsKillBody(String name) {
    return 'Anything running inside $name on the computer will be stopped.';
  }

  @override
  String get sessionsKill => 'End Session';

  @override
  String get sessionsRenameTitle => 'Rename session';

  @override
  String get sessionsForget => 'Remove from list';

  @override
  String get sessionsForgetBody =>
      'This only removes the shortcut. Anything running on the computer keeps running.';

  @override
  String get sessionsNew => 'New Session';

  @override
  String sessionsTmuxMissingTitle(String name) {
    return '$name is not installed';
  }

  @override
  String sessionsTmuxMissingBody(String name) {
    return 'Persistent sessions need $name on the computer. Install it there, choose a different multiplexer for this computer, or use a direct terminal.';
  }

  @override
  String get sessionsUseDirect => 'Use direct terminal';

  @override
  String get sessionsAttached => 'Attached';

  @override
  String sessionsWindows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count windows',
      one: '1 window',
    );
    return '$_temp0';
  }

  @override
  String get terminalTitle => 'Terminal';

  @override
  String terminalConnecting(String host) {
    return 'Connecting to $host…';
  }

  @override
  String get terminalDisconnected => 'Connection lost';

  @override
  String get terminalSessionInfo => 'Session Info';

  @override
  String get terminalSendCommand => 'Send Command';

  @override
  String get terminalOpenFilesHere => 'Open Files Here';

  @override
  String get terminalFontSize => 'Font size';

  @override
  String get terminalKeepScreenOn => 'Keep screen on';

  @override
  String get terminalSearch => 'Search';

  @override
  String get terminalSearchHint => 'Find in terminal';

  @override
  String get terminalSearchNoResults => 'No matches';

  @override
  String terminalSearchResult(int index, int total) {
    return '$index of $total';
  }

  @override
  String get terminalPaste => 'Paste';

  @override
  String terminalPasteConfirmTitle(int lines) {
    return 'Paste $lines lines?';
  }

  @override
  String get terminalPasteConfirmBody =>
      'Multi-line text runs each line as soon as it is pasted.';

  @override
  String get terminalCopySelection => 'Copy';

  @override
  String get terminalTabs => 'Terminals';

  @override
  String terminalSwitched(String name) {
    return 'Switched to $name';
  }

  @override
  String get terminalSwipeHint =>
      'Swipe left or right with two fingers to switch terminals, or tap the title above.';

  @override
  String get terminalNoTabs => 'No terminals open';

  @override
  String get terminalCloseTab => 'Close terminal';

  @override
  String get terminalCloseTabConfirm =>
      'Close this terminal? A direct session ends; a persistent one keeps running on the computer.';

  @override
  String terminalExitedWithCode(int code) {
    return 'Session ended (exit code $code)';
  }

  @override
  String get terminalExited => 'Session ended';

  @override
  String terminalAttachedTo(String name) {
    return 'tmux: $name';
  }

  @override
  String get commandsTitle => 'Commands';

  @override
  String get commandsEmptyTitle => 'No commands yet';

  @override
  String get commandsEmptyBody =>
      'Save the commands you type most, then run them with one tap.';

  @override
  String get commandsAdd => 'Add Command';

  @override
  String get commandNew => 'New Command';

  @override
  String get commandEdit => 'Edit Command';

  @override
  String get commandFieldName => 'Name';

  @override
  String get commandFieldCommand => 'Command';

  @override
  String get commandFieldScope => 'Available in';

  @override
  String get commandFieldHost => 'Computer';

  @override
  String get commandFieldProject => 'Project';

  @override
  String get commandFieldWorkingDirectory => 'Working directory';

  @override
  String get commandFieldExecutionMode => 'Run as';

  @override
  String get commandFieldConfirmation => 'Confirmation';

  @override
  String get commandFieldSessionMode => 'Session';

  @override
  String get commandFavorite => 'Show in Quick Actions';

  @override
  String get commandScopeGlobal => 'Everywhere';

  @override
  String get commandScopeHost => 'One computer';

  @override
  String get commandScopeProject => 'One project';

  @override
  String get commandModeInteractive => 'Interactive terminal';

  @override
  String get commandModeOneShot => 'One-shot command';

  @override
  String get commandModeInteractiveHelp =>
      'Opens a terminal. Use for tools that need input.';

  @override
  String get commandModeOneShotHelp => 'Runs once and shows the output.';

  @override
  String get commandConfirmNone => 'None';

  @override
  String get commandConfirmAlways => 'Always confirm';

  @override
  String get commandConfirmDangerous => 'Confirm if it looks destructive';

  @override
  String get commandVariablesTitle => 'Variables';

  @override
  String commandVariablesHelp(
    String projectPath,
    String hostName,
    String inputName,
  ) {
    return 'Use $projectPath, $hostName or $inputName in a command.';
  }

  @override
  String get commandDeleteTitle => 'Delete this command?';

  @override
  String get commandRunTitle => 'Run command';

  @override
  String get commandRunOn => 'Run on';

  @override
  String get commandPreview => 'This will run:';

  @override
  String get commandConfirmTitle => 'Run this command?';

  @override
  String get commandDangerTitle => 'This command looks destructive';

  @override
  String get commandDangerBody =>
      'The app cannot tell for certain whether a command is safe. Read it carefully before running it.';

  @override
  String get commandInputTitle => 'Fill in values';

  @override
  String get commandOutputTitle => 'Output';

  @override
  String get commandRunning => 'Running…';

  @override
  String commandExitCode(int code) {
    return 'Exit code $code';
  }

  @override
  String get commandNoOutput => 'The command produced no output.';

  @override
  String get commandOpenInTerminal => 'Open in terminal';

  @override
  String get presetsTitle => 'Presets';

  @override
  String get presetCodex => 'Codex';

  @override
  String get presetClaudeCode => 'Claude Code';

  @override
  String get presetGeminiCli => 'Gemini CLI';

  @override
  String get presetCustomCli => 'Custom CLI';

  @override
  String get presetGitStatus => 'Git Status';

  @override
  String get presetGitPull => 'Git Pull';

  @override
  String get presetDockerPs => 'Docker PS';

  @override
  String get presetDiskUsage => 'Disk Usage';

  @override
  String get presetSystemStatus => 'System Status';

  @override
  String get presetStartDevServer => 'Start Dev Server';

  @override
  String get presetsAiNote =>
      'AI tools run on the computer. Their sign-in stays there; this app never sees it.';

  @override
  String get keysTitle => 'Keys';

  @override
  String get keysEmptyTitle => 'No keys yet';

  @override
  String get keysEmptyBody =>
      'Import a private key, or generate one and add its public key to your computers.';

  @override
  String get keysImport => 'Import Key';

  @override
  String get keysGenerate => 'Generate Key';

  @override
  String get keysAddPassword => 'Save a Password';

  @override
  String get keyFieldName => 'Name';

  @override
  String get keyFieldPassphrase => 'Passphrase';

  @override
  String get keyFieldPassphraseHelp => 'Needed only if the key is protected.';

  @override
  String get keyFieldPassword => 'Password';

  @override
  String get keyPasteTitle => 'Paste private key';

  @override
  String get keyPasteHint => '-----BEGIN OPENSSH PRIVATE KEY-----';

  @override
  String get keyChooseFile => 'Choose file';

  @override
  String get keyPasteInstead => 'Paste instead';

  @override
  String get keyPublicKey => 'Public key';

  @override
  String get keyPublicKeyCopied => 'Public key copied';

  @override
  String get keyCopyPublicKey => 'Copy public key';

  @override
  String get keyFingerprint => 'Fingerprint';

  @override
  String get keyType => 'Type';

  @override
  String get keyProtected => 'Passphrase protected';

  @override
  String get keyRequireBiometric => 'Require device authentication';

  @override
  String get keyRequireBiometricHelp =>
      'Ask for biometrics or your device PIN before this credential is used.';

  @override
  String keyUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count computers',
      one: '1 computer',
      zero: 'no computers',
    );
    return 'Used by $_temp0';
  }

  @override
  String get keyDeleteTitle => 'Delete this credential?';

  @override
  String get keyDeleteBody =>
      'It will be removed from this device\'s secure storage and detached from any computer using it.';

  @override
  String get keyPrivateHidden =>
      'The private key is stored securely and is not shown again.';

  @override
  String get keyGenerateTitle => 'Generate a key';

  @override
  String get keyGenerateBody =>
      'Creates an Ed25519 key on this device. Add its public key to a computer\'s authorized_keys file to use it.';

  @override
  String get keyGeneratedTitle => 'Key created';

  @override
  String get keyGeneratedBody =>
      'Copy the public key and add it to the computer you want to reach.';

  @override
  String get keyImportFailed => 'That key could not be read.';

  @override
  String get keyPassphraseRequired => 'This key is protected by a passphrase.';

  @override
  String get keyPassphraseWrong => 'That passphrase did not unlock the key.';

  @override
  String get keySavePassphrase => 'Remember passphrase';

  @override
  String get filesTitle => 'Files';

  @override
  String get filesEmptyFolder => 'This folder is empty';

  @override
  String get filesLoadFailed => 'Could not open this folder';

  @override
  String get filesParent => 'Up one level';

  @override
  String get filesShowHidden => 'Show hidden files';

  @override
  String get filesSortName => 'Name';

  @override
  String get filesSortSize => 'Size';

  @override
  String get filesSortModified => 'Modified';

  @override
  String get filesSortBy => 'Sort by';

  @override
  String get filesNewFolderTitle => 'New folder';

  @override
  String get filesNewFolderHint => 'Folder name';

  @override
  String get filesRenameTitle => 'Rename';

  @override
  String get filesDeleteFileTitle => 'Delete this file?';

  @override
  String get filesDeleteFolderTitle => 'Delete this folder?';

  @override
  String filesDeleteFolderBody(String name) {
    return '$name and everything inside it will be deleted. This cannot be undone.';
  }

  @override
  String filesDeleteFolderCount(int count) {
    return 'About $count items will be deleted.';
  }

  @override
  String get filesDeleteRecursive => 'Delete folder and contents';

  @override
  String get filesUploadTitle => 'Upload';

  @override
  String get filesDownloadTitle => 'Download';

  @override
  String filesTransferring(String done, String total) {
    return '$done of $total';
  }

  @override
  String get filesTransferComplete => 'Finished';

  @override
  String get filesTransferFailed => 'Transfer failed';

  @override
  String get filesTransferCancelled => 'Cancelled';

  @override
  String get filesTransfersTitle => 'Transfers';

  @override
  String get filesOpenInViewer => 'Open';

  @override
  String get filesTooLargeToView => 'This file is too large to open here.';

  @override
  String get filesSaveChanges => 'Save changes';

  @override
  String get filesSaved => 'Saved';

  @override
  String get filesUnsavedTitle => 'Discard changes?';

  @override
  String get filesUnsavedBody =>
      'Your edits have not been saved to the computer.';

  @override
  String get filesReadOnlyNote => 'Read-only viewer';

  @override
  String get filesEditNote =>
      'Editing is meant for small files, not full development.';

  @override
  String get filesPathCopied => 'Path copied';

  @override
  String filesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String get forwardingTitle => 'Port Forwarding';

  @override
  String get forwardingEmptyTitle => 'No forwards yet';

  @override
  String get forwardingEmptyBody =>
      'Forward a port to reach a remote service from this phone, or expose a local one to the computer.';

  @override
  String get forwardingAdd => 'Add Forward';

  @override
  String get forwardNew => 'New Forward';

  @override
  String get forwardEdit => 'Edit Forward';

  @override
  String get forwardFieldName => 'Name';

  @override
  String get forwardFieldHost => 'Computer';

  @override
  String get forwardFieldType => 'Type';

  @override
  String get forwardFieldListenPort => 'Listen port';

  @override
  String get forwardFieldListenAddress => 'Listen address';

  @override
  String get forwardFieldTargetHost => 'Destination host';

  @override
  String get forwardFieldTargetPort => 'Destination port';

  @override
  String get forwardTypeLocal => 'Local';

  @override
  String get forwardTypeRemote => 'Remote';

  @override
  String get forwardTypeDynamic => 'Dynamic (SOCKS5)';

  @override
  String get forwardTypeLocalHelp =>
      'Opens a port on this phone that reaches a service on the computer\'s network.';

  @override
  String get forwardTypeRemoteHelp =>
      'Opens a port on the computer that reaches a service on this phone.';

  @override
  String get forwardTypeDynamicHelp =>
      'Runs a SOCKS5 proxy on this phone that routes through the computer.';

  @override
  String get forwardActive => 'Active';

  @override
  String get forwardInactive => 'Stopped';

  @override
  String forwardStarted(int port) {
    return 'Listening on port $port';
  }

  @override
  String forwardConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count connections',
      one: '1 connection',
      zero: 'No connections',
    );
    return '$_temp0';
  }

  @override
  String get forwardDeleteTitle => 'Delete this forward?';

  @override
  String get forwardAdvancedNote =>
      'Port forwarding is an advanced tool. It stops when the SSH connection closes.';

  @override
  String get wolTitle => 'Wake-on-LAN';

  @override
  String get wolFieldMac => 'MAC address';

  @override
  String get wolFieldMacHint => '00:1A:2B:3C:4D:5E';

  @override
  String get wolFieldBroadcast => 'Broadcast address';

  @override
  String get wolFieldPort => 'Port';

  @override
  String get wolEnable => 'Enable Wake-on-LAN';

  @override
  String get wolSent => 'Wake packet sent';

  @override
  String get wolBestEffort =>
      'Wake-on-LAN is best-effort. It normally works only on the same network as the computer.';

  @override
  String get wolInvalidMac => 'Enter a MAC address like 00:1A:2B:3C:4D:5E.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTerminal => 'Terminal';

  @override
  String get settingsSsh => 'SSH';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsTerminalTheme => 'Terminal theme';

  @override
  String get settingsTerminalFont => 'Terminal font';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsCursorStyle => 'Cursor style';

  @override
  String get settingsCursorBlock => 'Block';

  @override
  String get settingsCursorUnderline => 'Underline';

  @override
  String get settingsCursorBar => 'Bar';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsKeepAwake => 'Keep screen awake in terminal';

  @override
  String get settingsScrollback => 'Scrollback lines';

  @override
  String get settingsAccessoryKeys => 'Accessory key rows';

  @override
  String get settingsAccessoryKeysHelp =>
      'Choose the keys shown above the keyboard.';

  @override
  String get settingsCopyOnSelect => 'Copy on select';

  @override
  String get settingsPasteConfirm => 'Confirm multi-line paste';

  @override
  String get settingsDefaultSession => 'Default session type';

  @override
  String get settingsKeepalive => 'Keepalive interval';

  @override
  String get settingsConnectTimeout => 'Connection timeout';

  @override
  String get settingsAuthTimeout => 'Authentication timeout';

  @override
  String get settingsTerminalType => 'Terminal type';

  @override
  String get settingsReconnect => 'Reconnect behaviour';

  @override
  String get settingsReconnectAsk => 'Ask me';

  @override
  String get settingsReconnectOnce => 'Retry once';

  @override
  String get settingsReconnectBounded => 'Retry a few times';

  @override
  String get settingsMaxReconnects => 'Maximum retries';

  @override
  String get computerFieldMultiplexer => 'Persistent sessions';

  @override
  String get computerFieldMultiplexerHelp =>
      'Which terminal multiplexer anchors this computer\'s persistent sessions. It must already be installed there.';

  @override
  String get multiplexerTmux => 'tmux';

  @override
  String get multiplexerHerdr => 'Herdr';

  @override
  String get multiplexerHerdrHelp =>
      'Built for coding agents. Captures the mouse, so the terminal scrolls by dragging.';

  @override
  String get multiplexerTmuxHelp =>
      'Available on almost every machine. RelayShell turns on mouse mode so the terminal scrolls.';

  @override
  String get settingsDefaultMultiplexer => 'Default for new computers';

  @override
  String multiplexerUnavailable(String name) {
    return '$name is not installed on this computer.';
  }

  @override
  String multiplexerCannotRename(String name) {
    return '$name cannot rename a running session.';
  }

  @override
  String get terminalDetach => 'Detach, leave running';

  @override
  String get settingsTmuxPrefix => 'tmux session prefix';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockHelp =>
      'Require biometrics or your device PIN to open the app.';

  @override
  String get settingsAppLockTimeout => 'Lock after';

  @override
  String get settingsLockImmediately => 'Immediately';

  @override
  String get settingsLockOneMinute => '1 minute';

  @override
  String get settingsLockFiveMinutes => '5 minutes';

  @override
  String get settingsLockFifteenMinutes => '15 minutes';

  @override
  String get settingsCredentialBiometric =>
      'Protect new credentials with device authentication';

  @override
  String get settingsTrustedKeys => 'Trusted host keys';

  @override
  String settingsTrustedKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count computers',
      one: '1 computer',
      zero: 'None trusted',
    );
    return '$_temp0';
  }

  @override
  String get settingsClearClipboard => 'Clear clipboard after copying secrets';

  @override
  String get settingsClearClipboardDelay => 'Clear after';

  @override
  String get settingsExport => 'Export configuration';

  @override
  String get settingsExportHelp =>
      'Saves computers, projects, commands and settings. Never includes keys or passwords.';

  @override
  String get settingsImport => 'Import configuration';

  @override
  String get settingsImportHelp =>
      'Adds the contents of a backup file. Existing data is kept.';

  @override
  String get settingsReset => 'Reset app';

  @override
  String get settingsResetHelp =>
      'Deletes all local data and stored credentials.';

  @override
  String get settingsResetTitle => 'Reset the app?';

  @override
  String get settingsResetBody =>
      'Every computer, project, command, session and stored credential on this device will be deleted. Nothing on your remote machines changes. This cannot be undone.';

  @override
  String get settingsResetConfirm => 'Delete everything';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String settingsSeconds(int count) {
    return '$count s';
  }

  @override
  String settingsLines(int count) {
    return '$count lines';
  }

  @override
  String get importTitle => 'Import configuration';

  @override
  String get importIncludePreferences => 'Also restore settings';

  @override
  String importSuccess(int count) {
    return 'Imported $count items.';
  }

  @override
  String get importWarnings => 'Some items needed adjusting';

  @override
  String get importFailed => 'That file could not be imported.';

  @override
  String get exportSuccess => 'Configuration exported.';

  @override
  String get exportNoSecretsNotice =>
      'Keys and passwords are never included in an export.';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutTagline => 'A mobile control center for remote development.';

  @override
  String get aboutPrivacyTitle => 'Privacy';

  @override
  String get aboutPrivacyBody =>
      'This app has no account and no server of its own. Terminal output, commands, keys, passwords and remote files stay on your device and your computers.';

  @override
  String get aboutOpenSource => 'Open-source licences';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Computers, projects, commands, sessions';

  @override
  String get searchEmpty => 'Nothing matches that.';

  @override
  String get searchLocalOnly => 'Searches what is saved on this device.';

  @override
  String get searchSectionComputers => 'Computers';

  @override
  String get searchSectionProjects => 'Projects';

  @override
  String get searchSectionCommands => 'Commands';

  @override
  String get searchSectionSessions => 'Sessions';

  @override
  String get lockTitle => 'RelayShell is locked';

  @override
  String get lockBody => 'Authenticate to continue.';

  @override
  String get lockFailed => 'Authentication was not completed.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorGeneric => 'Could not complete that action.';

  @override
  String get errorNotConnected => 'Not connected to this computer.';

  @override
  String get errorRequired => 'Required';

  @override
  String get errorInvalidPort => 'Enter a port between 1 and 65535.';

  @override
  String get errorInvalidNumber => 'Enter a number.';

  @override
  String get errorNameTaken => 'That name is already used.';

  @override
  String get errorNoHosts => 'Add a computer first.';

  @override
  String get confirmDelete => 'Delete';

  @override
  String get confirmCannotUndo => 'This cannot be undone.';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeDaysAgo(int count) {
    return '$count days ago';
  }
}
