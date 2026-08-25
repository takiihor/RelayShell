import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RelayShell'**
  String get appTitle;

  /// No description provided for @appShortTitle.
  ///
  /// In en, this message translates to:
  /// **'RelayShell'**
  String get appShortTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navComputers.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get navComputers;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @moreCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get moreCommands;

  /// No description provided for @moreKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get moreKeys;

  /// No description provided for @moreForwarding.
  ///
  /// In en, this message translates to:
  /// **'Port Forwarding'**
  String get moreForwarding;

  /// No description provided for @moreSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreSettings;

  /// No description provided for @moreAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get moreAbout;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get actionDuplicate;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get actionRetry;

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get actionConnect;

  /// No description provided for @actionDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get actionDisconnect;

  /// No description provided for @actionReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get actionReconnect;

  /// No description provided for @actionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get actionResume;

  /// No description provided for @actionRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get actionRun;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get actionCopyPath;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get actionTrust;

  /// No description provided for @actionBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get actionBlock;

  /// No description provided for @actionUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get actionUnlock;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionTest.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get actionTest;

  /// No description provided for @actionWake.
  ///
  /// In en, this message translates to:
  /// **'Wake'**
  String get actionWake;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get actionStop;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get actionGenerate;

  /// No description provided for @actionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get actionUpload;

  /// No description provided for @actionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get actionDownload;

  /// No description provided for @actionNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get actionNewFolder;

  /// No description provided for @actionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get actionSelectAll;

  /// No description provided for @actionShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get actionShowDetails;

  /// No description provided for @homeContinueTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeContinueTitle;

  /// No description provided for @homeComputersTitle.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get homeComputersTitle;

  /// No description provided for @homeProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get homeProjectsTitle;

  /// No description provided for @homeQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get homeQuickActionsTitle;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a computer you can reach over SSH to get started.'**
  String get homeEmptyBody;

  /// No description provided for @homeAddComputer.
  ///
  /// In en, this message translates to:
  /// **'Add Computer'**
  String get homeAddComputer;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @statusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get statusChecking;

  /// No description provided for @statusReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get statusReachable;

  /// No description provided for @statusUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get statusUnreachable;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get statusConnecting;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusResolving.
  ///
  /// In en, this message translates to:
  /// **'Looking up address'**
  String get statusResolving;

  /// No description provided for @statusHandshaking.
  ///
  /// In en, this message translates to:
  /// **'Negotiating'**
  String get statusHandshaking;

  /// No description provided for @statusVerifyingHost.
  ///
  /// In en, this message translates to:
  /// **'Verifying identity'**
  String get statusVerifyingHost;

  /// No description provided for @statusAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get statusAuthenticating;

  /// No description provided for @statusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get statusReconnecting;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @computersTitle.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get computersTitle;

  /// No description provided for @computersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No computers yet'**
  String get computersEmptyTitle;

  /// No description provided for @computersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a computer that you can access through SSH.'**
  String get computersEmptyBody;

  /// No description provided for @computersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Computer'**
  String get computersAdd;

  /// No description provided for @computerNew.
  ///
  /// In en, this message translates to:
  /// **'New Computer'**
  String get computerNew;

  /// No description provided for @computerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Computer'**
  String get computerEdit;

  /// No description provided for @computerFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get computerFieldName;

  /// No description provided for @computerFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'Home PC'**
  String get computerFieldNameHint;

  /// No description provided for @computerFieldHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname or IP'**
  String get computerFieldHostname;

  /// No description provided for @computerFieldHostnameHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.10 or server.example.com'**
  String get computerFieldHostnameHint;

  /// No description provided for @computerFieldPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get computerFieldPort;

  /// No description provided for @computerFieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get computerFieldUsername;

  /// No description provided for @computerFieldStartupDirectory.
  ///
  /// In en, this message translates to:
  /// **'Startup directory'**
  String get computerFieldStartupDirectory;

  /// No description provided for @computerFieldStartupDirectoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. Terminals open here.'**
  String get computerFieldStartupDirectoryHelp;

  /// No description provided for @computerFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get computerFieldNotes;

  /// No description provided for @computerFieldNotesHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. Only you can see these.'**
  String get computerFieldNotesHelp;

  /// No description provided for @computerFieldPlatform.
  ///
  /// In en, this message translates to:
  /// **'Remote shell'**
  String get computerFieldPlatform;

  /// No description provided for @computerFieldPlatformHelp.
  ///
  /// In en, this message translates to:
  /// **'Determines how paths are quoted and whether tmux is offered.'**
  String get computerFieldPlatformHelp;

  /// No description provided for @computerFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get computerFieldColor;

  /// No description provided for @computerSectionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get computerSectionConnection;

  /// No description provided for @computerSectionAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get computerSectionAuthentication;

  /// No description provided for @computerSectionOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get computerSectionOptions;

  /// No description provided for @computerSectionWol.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN'**
  String get computerSectionWol;

  /// No description provided for @computerFavorite.
  ///
  /// In en, this message translates to:
  /// **'Pin to Home'**
  String get computerFavorite;

  /// No description provided for @computerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this computer?'**
  String get computerDeleteTitle;

  /// No description provided for @computerDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its projects, commands, saved sessions and forwards will be deleted too. Nothing on the remote machine changes.'**
  String get computerDeleteBody;

  /// No description provided for @computerDuplicateSuffix.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get computerDuplicateSuffix;

  /// No description provided for @computerNoCredential.
  ///
  /// In en, this message translates to:
  /// **'No credential selected'**
  String get computerNoCredential;

  /// No description provided for @computerOpenTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open Terminal'**
  String get computerOpenTerminal;

  /// No description provided for @computerNewTerminal.
  ///
  /// In en, this message translates to:
  /// **'New Terminal'**
  String get computerNewTerminal;

  /// No description provided for @computerResumeSession.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get computerResumeSession;

  /// No description provided for @computerFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get computerFiles;

  /// No description provided for @computerProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get computerProjects;

  /// No description provided for @computerRunCommand.
  ///
  /// In en, this message translates to:
  /// **'Run Command'**
  String get computerRunCommand;

  /// No description provided for @computerForwarding.
  ///
  /// In en, this message translates to:
  /// **'Port Forwarding'**
  String get computerForwarding;

  /// No description provided for @computerLastConnected.
  ///
  /// In en, this message translates to:
  /// **'Last connected {when}'**
  String computerLastConnected(String when);

  /// No description provided for @computerNeverConnected.
  ///
  /// In en, this message translates to:
  /// **'Never connected'**
  String get computerNeverConnected;

  /// No description provided for @authMethodPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'SSH private key'**
  String get authMethodPrivateKey;

  /// No description provided for @authMethodPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authMethodPassword;

  /// No description provided for @authMethodKeyboardInteractive.
  ///
  /// In en, this message translates to:
  /// **'Keyboard-interactive'**
  String get authMethodKeyboardInteractive;

  /// No description provided for @authMethodAgent.
  ///
  /// In en, this message translates to:
  /// **'SSH agent'**
  String get authMethodAgent;

  /// No description provided for @authMethodRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Key authentication is recommended.'**
  String get authMethodRecommendation;

  /// No description provided for @authSelectCredential.
  ///
  /// In en, this message translates to:
  /// **'Credential'**
  String get authSelectCredential;

  /// No description provided for @authNoKeysYet.
  ///
  /// In en, this message translates to:
  /// **'No keys yet'**
  String get authNoKeysYet;

  /// No description provided for @authAddKey.
  ///
  /// In en, this message translates to:
  /// **'Add a key'**
  String get authAddKey;

  /// No description provided for @authSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get authSavePassword;

  /// No description provided for @authSavePasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Stored in this device\'s secure storage. Leave off to be asked each time.'**
  String get authSavePasswordHelp;

  /// No description provided for @authAgentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SSH agent authentication is not available on this device.'**
  String get authAgentUnavailable;

  /// No description provided for @testConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnectionTitle;

  /// No description provided for @testConnectionRunning.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get testConnectionRunning;

  /// No description provided for @testConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully.'**
  String get testConnectionSuccess;

  /// No description provided for @testConnectionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional. You can save without testing.'**
  String get testConnectionOptional;

  /// No description provided for @hostKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify this computer'**
  String get hostKeyTitle;

  /// No description provided for @hostKeyBody.
  ///
  /// In en, this message translates to:
  /// **'This is the first time you have connected to {hostname}. Check the fingerprint matches the one on the computer before trusting it.'**
  String hostKeyBody(String hostname);

  /// No description provided for @hostKeyType.
  ///
  /// In en, this message translates to:
  /// **'Key type'**
  String get hostKeyType;

  /// No description provided for @hostKeyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint'**
  String get hostKeyFingerprint;

  /// No description provided for @hostKeyHint.
  ///
  /// In en, this message translates to:
  /// **'On the computer, run: ssh-keygen -lf /etc/ssh/ssh_host_{type}_key.pub'**
  String hostKeyHint(String type);

  /// No description provided for @hostKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning: identity changed'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyChangedBody.
  ///
  /// In en, this message translates to:
  /// **'The SSH identity of this computer has changed. This can mean the server was rebuilt — or that something is intercepting the connection.'**
  String get hostKeyChangedBody;

  /// No description provided for @hostKeyChangedSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get hostKeyChangedSaved;

  /// No description provided for @hostKeyChangedReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get hostKeyChangedReceived;

  /// No description provided for @hostKeyChangedBlocked.
  ///
  /// In en, this message translates to:
  /// **'The connection has been blocked.'**
  String get hostKeyChangedBlocked;

  /// No description provided for @hostKeyForget.
  ///
  /// In en, this message translates to:
  /// **'Forget saved key'**
  String get hostKeyForget;

  /// No description provided for @hostKeyForgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Forget the saved key for {hostname}? The next connection will ask you to verify it again.'**
  String hostKeyForgetConfirm(String hostname);

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @projectsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectsEmptyTitle;

  /// No description provided for @projectsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A project links a remote folder with terminal sessions and reusable actions.'**
  String get projectsEmptyBody;

  /// No description provided for @projectsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get projectsAdd;

  /// No description provided for @projectNew.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get projectNew;

  /// No description provided for @projectEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get projectEdit;

  /// No description provided for @projectFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get projectFieldName;

  /// No description provided for @projectFieldHost.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get projectFieldHost;

  /// No description provided for @projectFieldPath.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get projectFieldPath;

  /// No description provided for @projectFieldPathHint.
  ///
  /// In en, this message translates to:
  /// **'~/projects/my-app'**
  String get projectFieldPathHint;

  /// No description provided for @projectFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get projectFieldDescription;

  /// No description provided for @projectFieldSessionMode.
  ///
  /// In en, this message translates to:
  /// **'Default session'**
  String get projectFieldSessionMode;

  /// No description provided for @projectFieldTmuxName.
  ///
  /// In en, this message translates to:
  /// **'tmux session name'**
  String get projectFieldTmuxName;

  /// No description provided for @projectFieldTmuxNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to generate one automatically.'**
  String get projectFieldTmuxNameHelp;

  /// No description provided for @projectFavorite.
  ///
  /// In en, this message translates to:
  /// **'Pin to Home'**
  String get projectFavorite;

  /// No description provided for @projectActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get projectActionsTitle;

  /// No description provided for @projectFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get projectFilesTitle;

  /// No description provided for @projectBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse Project'**
  String get projectBrowseFiles;

  /// No description provided for @projectOpenTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open Terminal'**
  String get projectOpenTerminal;

  /// No description provided for @projectNoActions.
  ///
  /// In en, this message translates to:
  /// **'No actions yet'**
  String get projectNoActions;

  /// No description provided for @projectNoActionsBody.
  ///
  /// In en, this message translates to:
  /// **'Add a command to run it here with one tap.'**
  String get projectNoActionsBody;

  /// No description provided for @projectAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add Action'**
  String get projectAddAction;

  /// No description provided for @projectDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this project?'**
  String get projectDeleteTitle;

  /// No description provided for @projectDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its commands and saved sessions will be deleted too. The remote folder is not touched.'**
  String get projectDeleteBody;

  /// No description provided for @projectLastOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened {when}'**
  String projectLastOpened(String when);

  /// No description provided for @sessionModeDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get sessionModeDirect;

  /// No description provided for @sessionModePersistent.
  ///
  /// In en, this message translates to:
  /// **'Persistent (tmux)'**
  String get sessionModePersistent;

  /// No description provided for @sessionModeDirectHelp.
  ///
  /// In en, this message translates to:
  /// **'A normal SSH shell. It ends if the connection drops.'**
  String get sessionModeDirectHelp;

  /// No description provided for @sessionModePersistentHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs inside tmux on the computer, so work survives a dropped connection.'**
  String get sessionModePersistentHelp;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionsEmptyTitle;

  /// No description provided for @sessionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Open a terminal or start a persistent session and it will appear here.'**
  String get sessionsEmptyBody;

  /// No description provided for @sessionsLive.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get sessionsLive;

  /// No description provided for @sessionsOpenTabs.
  ///
  /// In en, this message translates to:
  /// **'Open tabs'**
  String get sessionsOpenTabs;

  /// No description provided for @terminalStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get terminalStateConnecting;

  /// No description provided for @terminalStateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get terminalStateConnected;

  /// No description provided for @terminalStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get terminalStateDisconnected;

  /// No description provided for @terminalStateEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get terminalStateEnded;

  /// No description provided for @terminalStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get terminalStateFailed;

  /// No description provided for @sessionsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sessionsSaved;

  /// No description provided for @sessionsOnHost.
  ///
  /// In en, this message translates to:
  /// **'On {host}'**
  String sessionsOnHost(String host);

  /// No description provided for @sessionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check computer'**
  String get sessionsRefresh;

  /// No description provided for @sessionsKillTitle.
  ///
  /// In en, this message translates to:
  /// **'End this session?'**
  String get sessionsKillTitle;

  /// No description provided for @sessionsKillBody.
  ///
  /// In en, this message translates to:
  /// **'Anything running inside {name} on the computer will be stopped.'**
  String sessionsKillBody(String name);

  /// No description provided for @sessionsKill.
  ///
  /// In en, this message translates to:
  /// **'End Session'**
  String get sessionsKill;

  /// No description provided for @sessionsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get sessionsRenameTitle;

  /// No description provided for @sessionsForget.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get sessionsForget;

  /// No description provided for @sessionsForgetBody.
  ///
  /// In en, this message translates to:
  /// **'This only removes the shortcut. Anything running on the computer keeps running.'**
  String get sessionsForgetBody;

  /// No description provided for @sessionsNew.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get sessionsNew;

  /// No description provided for @sessionsTmuxMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'tmux is not installed'**
  String get sessionsTmuxMissingTitle;

  /// No description provided for @sessionsTmuxMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Persistent sessions need tmux on the computer. Install it there, or use a direct terminal.'**
  String get sessionsTmuxMissingBody;

  /// No description provided for @sessionsUseDirect.
  ///
  /// In en, this message translates to:
  /// **'Use direct terminal'**
  String get sessionsUseDirect;

  /// No description provided for @sessionsAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get sessionsAttached;

  /// No description provided for @sessionsWindows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 window} other{{count} windows}}'**
  String sessionsWindows(int count);

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// No description provided for @terminalConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {host}…'**
  String terminalConnecting(String host);

  /// No description provided for @terminalDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get terminalDisconnected;

  /// No description provided for @terminalSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get terminalSessionInfo;

  /// No description provided for @terminalSendCommand.
  ///
  /// In en, this message translates to:
  /// **'Send Command'**
  String get terminalSendCommand;

  /// No description provided for @terminalOpenFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Open Files Here'**
  String get terminalOpenFilesHere;

  /// No description provided for @terminalFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get terminalFontSize;

  /// No description provided for @terminalKeepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get terminalKeepScreenOn;

  /// No description provided for @terminalSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get terminalSearch;

  /// No description provided for @terminalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find in terminal'**
  String get terminalSearchHint;

  /// No description provided for @terminalSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get terminalSearchNoResults;

  /// No description provided for @terminalSearchResult.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String terminalSearchResult(int index, int total);

  /// No description provided for @terminalPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalPaste;

  /// No description provided for @terminalPasteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste {lines} lines?'**
  String terminalPasteConfirmTitle(int lines);

  /// No description provided for @terminalPasteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Multi-line text runs each line as soon as it is pasted.'**
  String get terminalPasteConfirmBody;

  /// No description provided for @terminalCopySelection.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get terminalCopySelection;

  /// No description provided for @terminalTabs.
  ///
  /// In en, this message translates to:
  /// **'Terminals'**
  String get terminalTabs;

  /// No description provided for @terminalSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String terminalSwitched(String name);

  /// No description provided for @terminalNoTabs.
  ///
  /// In en, this message translates to:
  /// **'No terminals open'**
  String get terminalNoTabs;

  /// No description provided for @terminalCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close terminal'**
  String get terminalCloseTab;

  /// No description provided for @terminalCloseTabConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close this terminal? A direct session ends; a persistent one keeps running on the computer.'**
  String get terminalCloseTabConfirm;

  /// No description provided for @terminalExitedWithCode.
  ///
  /// In en, this message translates to:
  /// **'Session ended (exit code {code})'**
  String terminalExitedWithCode(int code);

  /// No description provided for @terminalExited.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get terminalExited;

  /// No description provided for @terminalAttachedTo.
  ///
  /// In en, this message translates to:
  /// **'tmux: {name}'**
  String terminalAttachedTo(String name);

  /// No description provided for @commandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commandsTitle;

  /// No description provided for @commandsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No commands yet'**
  String get commandsEmptyTitle;

  /// No description provided for @commandsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save the commands you type most, then run them with one tap.'**
  String get commandsEmptyBody;

  /// No description provided for @commandsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Command'**
  String get commandsAdd;

  /// No description provided for @commandNew.
  ///
  /// In en, this message translates to:
  /// **'New Command'**
  String get commandNew;

  /// No description provided for @commandEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Command'**
  String get commandEdit;

  /// No description provided for @commandFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commandFieldName;

  /// No description provided for @commandFieldCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get commandFieldCommand;

  /// No description provided for @commandFieldScope.
  ///
  /// In en, this message translates to:
  /// **'Available in'**
  String get commandFieldScope;

  /// No description provided for @commandFieldHost.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get commandFieldHost;

  /// No description provided for @commandFieldProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get commandFieldProject;

  /// No description provided for @commandFieldWorkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get commandFieldWorkingDirectory;

  /// No description provided for @commandFieldExecutionMode.
  ///
  /// In en, this message translates to:
  /// **'Run as'**
  String get commandFieldExecutionMode;

  /// No description provided for @commandFieldConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get commandFieldConfirmation;

  /// No description provided for @commandFieldSessionMode.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get commandFieldSessionMode;

  /// No description provided for @commandFavorite.
  ///
  /// In en, this message translates to:
  /// **'Show in Quick Actions'**
  String get commandFavorite;

  /// No description provided for @commandScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Everywhere'**
  String get commandScopeGlobal;

  /// No description provided for @commandScopeHost.
  ///
  /// In en, this message translates to:
  /// **'One computer'**
  String get commandScopeHost;

  /// No description provided for @commandScopeProject.
  ///
  /// In en, this message translates to:
  /// **'One project'**
  String get commandScopeProject;

  /// No description provided for @commandModeInteractive.
  ///
  /// In en, this message translates to:
  /// **'Interactive terminal'**
  String get commandModeInteractive;

  /// No description provided for @commandModeOneShot.
  ///
  /// In en, this message translates to:
  /// **'One-shot command'**
  String get commandModeOneShot;

  /// No description provided for @commandModeInteractiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Opens a terminal. Use for tools that need input.'**
  String get commandModeInteractiveHelp;

  /// No description provided for @commandModeOneShotHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs once and shows the output.'**
  String get commandModeOneShotHelp;

  /// No description provided for @commandConfirmNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commandConfirmNone;

  /// No description provided for @commandConfirmAlways.
  ///
  /// In en, this message translates to:
  /// **'Always confirm'**
  String get commandConfirmAlways;

  /// No description provided for @commandConfirmDangerous.
  ///
  /// In en, this message translates to:
  /// **'Confirm if it looks destructive'**
  String get commandConfirmDangerous;

  /// No description provided for @commandVariablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get commandVariablesTitle;

  /// No description provided for @commandVariablesHelp.
  ///
  /// In en, this message translates to:
  /// **'Use {projectPath}, {hostName} or {inputName} in a command.'**
  String commandVariablesHelp(
    String projectPath,
    String hostName,
    String inputName,
  );

  /// No description provided for @commandDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this command?'**
  String get commandDeleteTitle;

  /// No description provided for @commandRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get commandRunTitle;

  /// No description provided for @commandRunOn.
  ///
  /// In en, this message translates to:
  /// **'Run on'**
  String get commandRunOn;

  /// No description provided for @commandPreview.
  ///
  /// In en, this message translates to:
  /// **'This will run:'**
  String get commandPreview;

  /// No description provided for @commandConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Run this command?'**
  String get commandConfirmTitle;

  /// No description provided for @commandDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'This command looks destructive'**
  String get commandDangerTitle;

  /// No description provided for @commandDangerBody.
  ///
  /// In en, this message translates to:
  /// **'The app cannot tell for certain whether a command is safe. Read it carefully before running it.'**
  String get commandDangerBody;

  /// No description provided for @commandInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in values'**
  String get commandInputTitle;

  /// No description provided for @commandOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get commandOutputTitle;

  /// No description provided for @commandRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get commandRunning;

  /// No description provided for @commandExitCode.
  ///
  /// In en, this message translates to:
  /// **'Exit code {code}'**
  String commandExitCode(int code);

  /// No description provided for @commandNoOutput.
  ///
  /// In en, this message translates to:
  /// **'The command produced no output.'**
  String get commandNoOutput;

  /// No description provided for @commandOpenInTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open in terminal'**
  String get commandOpenInTerminal;

  /// No description provided for @presetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presetsTitle;

  /// No description provided for @presetCodex.
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get presetCodex;

  /// No description provided for @presetClaudeCode.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get presetClaudeCode;

  /// No description provided for @presetGeminiCli.
  ///
  /// In en, this message translates to:
  /// **'Gemini CLI'**
  String get presetGeminiCli;

  /// No description provided for @presetCustomCli.
  ///
  /// In en, this message translates to:
  /// **'Custom CLI'**
  String get presetCustomCli;

  /// No description provided for @presetGitStatus.
  ///
  /// In en, this message translates to:
  /// **'Git Status'**
  String get presetGitStatus;

  /// No description provided for @presetGitPull.
  ///
  /// In en, this message translates to:
  /// **'Git Pull'**
  String get presetGitPull;

  /// No description provided for @presetDockerPs.
  ///
  /// In en, this message translates to:
  /// **'Docker PS'**
  String get presetDockerPs;

  /// No description provided for @presetDiskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk Usage'**
  String get presetDiskUsage;

  /// No description provided for @presetSystemStatus.
  ///
  /// In en, this message translates to:
  /// **'System Status'**
  String get presetSystemStatus;

  /// No description provided for @presetStartDevServer.
  ///
  /// In en, this message translates to:
  /// **'Start Dev Server'**
  String get presetStartDevServer;

  /// No description provided for @presetsAiNote.
  ///
  /// In en, this message translates to:
  /// **'AI tools run on the computer. Their sign-in stays there; this app never sees it.'**
  String get presetsAiNote;

  /// No description provided for @keysTitle.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get keysTitle;

  /// No description provided for @keysEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No keys yet'**
  String get keysEmptyTitle;

  /// No description provided for @keysEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import a private key, or generate one and add its public key to your computers.'**
  String get keysEmptyBody;

  /// No description provided for @keysImport.
  ///
  /// In en, this message translates to:
  /// **'Import Key'**
  String get keysImport;

  /// No description provided for @keysGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate Key'**
  String get keysGenerate;

  /// No description provided for @keysAddPassword.
  ///
  /// In en, this message translates to:
  /// **'Save a Password'**
  String get keysAddPassword;

  /// No description provided for @keyFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get keyFieldName;

  /// No description provided for @keyFieldPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get keyFieldPassphrase;

  /// No description provided for @keyFieldPassphraseHelp.
  ///
  /// In en, this message translates to:
  /// **'Needed only if the key is protected.'**
  String get keyFieldPassphraseHelp;

  /// No description provided for @keyFieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get keyFieldPassword;

  /// No description provided for @keyPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste private key'**
  String get keyPasteTitle;

  /// No description provided for @keyPasteHint.
  ///
  /// In en, this message translates to:
  /// **'-----BEGIN OPENSSH PRIVATE KEY-----'**
  String get keyPasteHint;

  /// No description provided for @keyChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get keyChooseFile;

  /// No description provided for @keyPasteInstead.
  ///
  /// In en, this message translates to:
  /// **'Paste instead'**
  String get keyPasteInstead;

  /// No description provided for @keyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get keyPublicKey;

  /// No description provided for @keyPublicKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied'**
  String get keyPublicKeyCopied;

  /// No description provided for @keyCopyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get keyCopyPublicKey;

  /// No description provided for @keyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get keyFingerprint;

  /// No description provided for @keyType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get keyType;

  /// No description provided for @keyProtected.
  ///
  /// In en, this message translates to:
  /// **'Passphrase protected'**
  String get keyProtected;

  /// No description provided for @keyRequireBiometric.
  ///
  /// In en, this message translates to:
  /// **'Require device authentication'**
  String get keyRequireBiometric;

  /// No description provided for @keyRequireBiometricHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask for biometrics or your device PIN before this credential is used.'**
  String get keyRequireBiometricHelp;

  /// No description provided for @keyUsedBy.
  ///
  /// In en, this message translates to:
  /// **'Used by {count, plural, =0{no computers} =1{1 computer} other{{count} computers}}'**
  String keyUsedBy(int count);

  /// No description provided for @keyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this credential?'**
  String get keyDeleteTitle;

  /// No description provided for @keyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from this device\'s secure storage and detached from any computer using it.'**
  String get keyDeleteBody;

  /// No description provided for @keyPrivateHidden.
  ///
  /// In en, this message translates to:
  /// **'The private key is stored securely and is not shown again.'**
  String get keyPrivateHidden;

  /// No description provided for @keyGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a key'**
  String get keyGenerateTitle;

  /// No description provided for @keyGenerateBody.
  ///
  /// In en, this message translates to:
  /// **'Creates an Ed25519 key on this device. Add its public key to a computer\'s authorized_keys file to use it.'**
  String get keyGenerateBody;

  /// No description provided for @keyGeneratedTitle.
  ///
  /// In en, this message translates to:
  /// **'Key created'**
  String get keyGeneratedTitle;

  /// No description provided for @keyGeneratedBody.
  ///
  /// In en, this message translates to:
  /// **'Copy the public key and add it to the computer you want to reach.'**
  String get keyGeneratedBody;

  /// No description provided for @keyImportFailed.
  ///
  /// In en, this message translates to:
  /// **'That key could not be read.'**
  String get keyImportFailed;

  /// No description provided for @keyPassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'This key is protected by a passphrase.'**
  String get keyPassphraseRequired;

  /// No description provided for @keyPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'That passphrase did not unlock the key.'**
  String get keyPassphraseWrong;

  /// No description provided for @keySavePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Remember passphrase'**
  String get keySavePassphrase;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @filesEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get filesEmptyFolder;

  /// No description provided for @filesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this folder'**
  String get filesLoadFailed;

  /// No description provided for @filesParent.
  ///
  /// In en, this message translates to:
  /// **'Up one level'**
  String get filesParent;

  /// No description provided for @filesShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get filesShowHidden;

  /// No description provided for @filesSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get filesSortName;

  /// No description provided for @filesSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get filesSortSize;

  /// No description provided for @filesSortModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get filesSortModified;

  /// No description provided for @filesSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get filesSortBy;

  /// No description provided for @filesNewFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get filesNewFolderTitle;

  /// No description provided for @filesNewFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get filesNewFolderHint;

  /// No description provided for @filesRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get filesRenameTitle;

  /// No description provided for @filesDeleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this file?'**
  String get filesDeleteFileTitle;

  /// No description provided for @filesDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this folder?'**
  String get filesDeleteFolderTitle;

  /// No description provided for @filesDeleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'{name} and everything inside it will be deleted. This cannot be undone.'**
  String filesDeleteFolderBody(String name);

  /// No description provided for @filesDeleteFolderCount.
  ///
  /// In en, this message translates to:
  /// **'About {count} items will be deleted.'**
  String filesDeleteFolderCount(int count);

  /// No description provided for @filesDeleteRecursive.
  ///
  /// In en, this message translates to:
  /// **'Delete folder and contents'**
  String get filesDeleteRecursive;

  /// No description provided for @filesUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get filesUploadTitle;

  /// No description provided for @filesDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get filesDownloadTitle;

  /// No description provided for @filesTransferring.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String filesTransferring(String done, String total);

  /// No description provided for @filesTransferComplete.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get filesTransferComplete;

  /// No description provided for @filesTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed'**
  String get filesTransferFailed;

  /// No description provided for @filesTransferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get filesTransferCancelled;

  /// No description provided for @filesTransfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get filesTransfersTitle;

  /// No description provided for @filesOpenInViewer.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get filesOpenInViewer;

  /// No description provided for @filesTooLargeToView.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to open here.'**
  String get filesTooLargeToView;

  /// No description provided for @filesSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get filesSaveChanges;

  /// No description provided for @filesSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get filesSaved;

  /// No description provided for @filesUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get filesUnsavedTitle;

  /// No description provided for @filesUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits have not been saved to the computer.'**
  String get filesUnsavedBody;

  /// No description provided for @filesReadOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Read-only viewer'**
  String get filesReadOnlyNote;

  /// No description provided for @filesEditNote.
  ///
  /// In en, this message translates to:
  /// **'Editing is meant for small files, not full development.'**
  String get filesEditNote;

  /// No description provided for @filesPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get filesPathCopied;

  /// No description provided for @filesItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 item} other{{count} items}}'**
  String filesItemCount(int count);

  /// No description provided for @forwardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Port Forwarding'**
  String get forwardingTitle;

  /// No description provided for @forwardingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No forwards yet'**
  String get forwardingEmptyTitle;

  /// No description provided for @forwardingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Forward a port to reach a remote service from this phone, or expose a local one to the computer.'**
  String get forwardingEmptyBody;

  /// No description provided for @forwardingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Forward'**
  String get forwardingAdd;

  /// No description provided for @forwardNew.
  ///
  /// In en, this message translates to:
  /// **'New Forward'**
  String get forwardNew;

  /// No description provided for @forwardEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Forward'**
  String get forwardEdit;

  /// No description provided for @forwardFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get forwardFieldName;

  /// No description provided for @forwardFieldHost.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get forwardFieldHost;

  /// No description provided for @forwardFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get forwardFieldType;

  /// No description provided for @forwardFieldListenPort.
  ///
  /// In en, this message translates to:
  /// **'Listen port'**
  String get forwardFieldListenPort;

  /// No description provided for @forwardFieldListenAddress.
  ///
  /// In en, this message translates to:
  /// **'Listen address'**
  String get forwardFieldListenAddress;

  /// No description provided for @forwardFieldTargetHost.
  ///
  /// In en, this message translates to:
  /// **'Destination host'**
  String get forwardFieldTargetHost;

  /// No description provided for @forwardFieldTargetPort.
  ///
  /// In en, this message translates to:
  /// **'Destination port'**
  String get forwardFieldTargetPort;

  /// No description provided for @forwardTypeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get forwardTypeLocal;

  /// No description provided for @forwardTypeRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get forwardTypeRemote;

  /// No description provided for @forwardTypeDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic (SOCKS5)'**
  String get forwardTypeDynamic;

  /// No description provided for @forwardTypeLocalHelp.
  ///
  /// In en, this message translates to:
  /// **'Opens a port on this phone that reaches a service on the computer\'s network.'**
  String get forwardTypeLocalHelp;

  /// No description provided for @forwardTypeRemoteHelp.
  ///
  /// In en, this message translates to:
  /// **'Opens a port on the computer that reaches a service on this phone.'**
  String get forwardTypeRemoteHelp;

  /// No description provided for @forwardTypeDynamicHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs a SOCKS5 proxy on this phone that routes through the computer.'**
  String get forwardTypeDynamicHelp;

  /// No description provided for @forwardActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get forwardActive;

  /// No description provided for @forwardInactive.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get forwardInactive;

  /// No description provided for @forwardStarted.
  ///
  /// In en, this message translates to:
  /// **'Listening on port {port}'**
  String forwardStarted(int port);

  /// No description provided for @forwardConnections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No connections} =1{1 connection} other{{count} connections}}'**
  String forwardConnections(int count);

  /// No description provided for @forwardDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this forward?'**
  String get forwardDeleteTitle;

  /// No description provided for @forwardAdvancedNote.
  ///
  /// In en, this message translates to:
  /// **'Port forwarding is an advanced tool. It stops when the SSH connection closes.'**
  String get forwardAdvancedNote;

  /// No description provided for @wolTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN'**
  String get wolTitle;

  /// No description provided for @wolFieldMac.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get wolFieldMac;

  /// No description provided for @wolFieldMacHint.
  ///
  /// In en, this message translates to:
  /// **'00:1A:2B:3C:4D:5E'**
  String get wolFieldMacHint;

  /// No description provided for @wolFieldBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast address'**
  String get wolFieldBroadcast;

  /// No description provided for @wolFieldPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get wolFieldPort;

  /// No description provided for @wolEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Wake-on-LAN'**
  String get wolEnable;

  /// No description provided for @wolSent.
  ///
  /// In en, this message translates to:
  /// **'Wake packet sent'**
  String get wolSent;

  /// No description provided for @wolBestEffort.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN is best-effort. It normally works only on the same network as the computer.'**
  String get wolBestEffort;

  /// No description provided for @wolInvalidMac.
  ///
  /// In en, this message translates to:
  /// **'Enter a MAC address like 00:1A:2B:3C:4D:5E.'**
  String get wolInvalidMac;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get settingsTerminal;

  /// No description provided for @settingsSsh.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get settingsSsh;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsTerminalTheme.
  ///
  /// In en, this message translates to:
  /// **'Terminal theme'**
  String get settingsTerminalTheme;

  /// No description provided for @settingsTerminalFont.
  ///
  /// In en, this message translates to:
  /// **'Terminal font'**
  String get settingsTerminalFont;

  /// No description provided for @settingsFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontSize;

  /// No description provided for @settingsCursorStyle.
  ///
  /// In en, this message translates to:
  /// **'Cursor style'**
  String get settingsCursorStyle;

  /// No description provided for @settingsCursorBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get settingsCursorBlock;

  /// No description provided for @settingsCursorUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get settingsCursorUnderline;

  /// No description provided for @settingsCursorBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get settingsCursorBar;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsKeepAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake in terminal'**
  String get settingsKeepAwake;

  /// No description provided for @settingsScrollback.
  ///
  /// In en, this message translates to:
  /// **'Scrollback lines'**
  String get settingsScrollback;

  /// No description provided for @settingsAccessoryKeys.
  ///
  /// In en, this message translates to:
  /// **'Accessory key rows'**
  String get settingsAccessoryKeys;

  /// No description provided for @settingsAccessoryKeysHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the keys shown above the keyboard.'**
  String get settingsAccessoryKeysHelp;

  /// No description provided for @settingsCopyOnSelect.
  ///
  /// In en, this message translates to:
  /// **'Copy on select'**
  String get settingsCopyOnSelect;

  /// No description provided for @settingsPasteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm multi-line paste'**
  String get settingsPasteConfirm;

  /// No description provided for @settingsDefaultSession.
  ///
  /// In en, this message translates to:
  /// **'Default session type'**
  String get settingsDefaultSession;

  /// No description provided for @settingsKeepalive.
  ///
  /// In en, this message translates to:
  /// **'Keepalive interval'**
  String get settingsKeepalive;

  /// No description provided for @settingsConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout'**
  String get settingsConnectTimeout;

  /// No description provided for @settingsAuthTimeout.
  ///
  /// In en, this message translates to:
  /// **'Authentication timeout'**
  String get settingsAuthTimeout;

  /// No description provided for @settingsTerminalType.
  ///
  /// In en, this message translates to:
  /// **'Terminal type'**
  String get settingsTerminalType;

  /// No description provided for @settingsReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect behaviour'**
  String get settingsReconnect;

  /// No description provided for @settingsReconnectAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask me'**
  String get settingsReconnectAsk;

  /// No description provided for @settingsReconnectOnce.
  ///
  /// In en, this message translates to:
  /// **'Retry once'**
  String get settingsReconnectOnce;

  /// No description provided for @settingsReconnectBounded.
  ///
  /// In en, this message translates to:
  /// **'Retry a few times'**
  String get settingsReconnectBounded;

  /// No description provided for @settingsMaxReconnects.
  ///
  /// In en, this message translates to:
  /// **'Maximum retries'**
  String get settingsMaxReconnects;

  /// No description provided for @settingsTmuxPrefix.
  ///
  /// In en, this message translates to:
  /// **'tmux session prefix'**
  String get settingsTmuxPrefix;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockHelp.
  ///
  /// In en, this message translates to:
  /// **'Require biometrics or your device PIN to open the app.'**
  String get settingsAppLockHelp;

  /// No description provided for @settingsAppLockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock after'**
  String get settingsAppLockTimeout;

  /// No description provided for @settingsLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get settingsLockImmediately;

  /// No description provided for @settingsLockOneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get settingsLockOneMinute;

  /// No description provided for @settingsLockFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get settingsLockFiveMinutes;

  /// No description provided for @settingsLockFifteenMinutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes'**
  String get settingsLockFifteenMinutes;

  /// No description provided for @settingsCredentialBiometric.
  ///
  /// In en, this message translates to:
  /// **'Protect new credentials with device authentication'**
  String get settingsCredentialBiometric;

  /// No description provided for @settingsTrustedKeys.
  ///
  /// In en, this message translates to:
  /// **'Trusted host keys'**
  String get settingsTrustedKeys;

  /// No description provided for @settingsTrustedKeysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None trusted} =1{1 computer} other{{count} computers}}'**
  String settingsTrustedKeysCount(int count);

  /// No description provided for @settingsClearClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clear clipboard after copying secrets'**
  String get settingsClearClipboard;

  /// No description provided for @settingsClearClipboardDelay.
  ///
  /// In en, this message translates to:
  /// **'Clear after'**
  String get settingsClearClipboardDelay;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export configuration'**
  String get settingsExport;

  /// No description provided for @settingsExportHelp.
  ///
  /// In en, this message translates to:
  /// **'Saves computers, projects, commands and settings. Never includes keys or passwords.'**
  String get settingsExportHelp;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get settingsImport;

  /// No description provided for @settingsImportHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds the contents of a backup file. Existing data is kept.'**
  String get settingsImportHelp;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get settingsReset;

  /// No description provided for @settingsResetHelp.
  ///
  /// In en, this message translates to:
  /// **'Deletes all local data and stored credentials.'**
  String get settingsResetHelp;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the app?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetBody.
  ///
  /// In en, this message translates to:
  /// **'Every computer, project, command, session and stored credential on this device will be deleted. Nothing on your remote machines changes. This cannot be undone.'**
  String get settingsResetBody;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get settingsResetConfirm;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String settingsSeconds(int count);

  /// No description provided for @settingsLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String settingsLines(int count);

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get importTitle;

  /// No description provided for @importIncludePreferences.
  ///
  /// In en, this message translates to:
  /// **'Also restore settings'**
  String get importIncludePreferences;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} items.'**
  String importSuccess(int count);

  /// No description provided for @importWarnings.
  ///
  /// In en, this message translates to:
  /// **'Some items needed adjusting'**
  String get importWarnings;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'That file could not be imported.'**
  String get importFailed;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Configuration exported.'**
  String get exportSuccess;

  /// No description provided for @exportNoSecretsNotice.
  ///
  /// In en, this message translates to:
  /// **'Keys and passwords are never included in an export.'**
  String get exportNoSecretsNotice;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A mobile control center for remote development.'**
  String get aboutTagline;

  /// No description provided for @aboutPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacyTitle;

  /// No description provided for @aboutPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'This app has no account and no server of its own. Terminal output, commands, keys, passwords and remote files stay on your device and your computers.'**
  String get aboutPrivacyBody;

  /// No description provided for @aboutOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutOpenSource;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Computers, projects, commands, sessions'**
  String get searchHint;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that.'**
  String get searchEmpty;

  /// No description provided for @searchLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Searches what is saved on this device.'**
  String get searchLocalOnly;

  /// No description provided for @searchSectionComputers.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get searchSectionComputers;

  /// No description provided for @searchSectionProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get searchSectionProjects;

  /// No description provided for @searchSectionCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get searchSectionCommands;

  /// No description provided for @searchSectionSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get searchSectionSessions;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'RelayShell is locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to continue.'**
  String get lockBody;

  /// No description provided for @lockFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication was not completed.'**
  String get lockFailed;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not complete that action.'**
  String get errorGeneric;

  /// No description provided for @errorNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to this computer.'**
  String get errorNotConnected;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get errorRequired;

  /// No description provided for @errorInvalidPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a port between 1 and 65535.'**
  String get errorInvalidPort;

  /// No description provided for @errorInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number.'**
  String get errorInvalidNumber;

  /// No description provided for @errorNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is already used.'**
  String get errorNameTaken;

  /// No description provided for @errorNoHosts.
  ///
  /// In en, this message translates to:
  /// **'Add a computer first.'**
  String get errorNoHosts;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get confirmDelete;

  /// No description provided for @confirmCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get confirmCannotUndo;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String timeDaysAgo(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
