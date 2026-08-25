# SPEC.md — RelayShell

**Status:** Product / Engineering Specification  
**Target:** Android + iOS  
**Primary stack:** Flutter  
**Document scope:** Full application design, not an MVP-only specification  
**Design principle:** Complete enough for production, but deliberately avoids unnecessary backend/cloud complexity.

---

## 1. Product Summary

RelayShell is a mobile-first application for controlling development computers and servers through SSH.

The product is not intended to reproduce a full Linux environment on the phone. Instead, the phone acts as a fast, convenient control surface for a user's existing Windows, macOS, Linux, VPS, NAS, or development machine.

The core model is:

```text
Phone
  ↓
Computer
  ↓
Project
  ↓
Session
  ↓
Action
```

A traditional SSH client starts with a blank terminal. RelayShell starts with what the user actually wants to do:

- open a computer;
- resume a working session;
- enter a project;
- start Codex / Claude Code / another CLI;
- run a saved command;
- manage remote files;
- inspect a service;
- reconnect to work already running.

The terminal remains a first-class feature, but it is not the entire product.

---

## 2. Product Goals

### 2.1 Primary goals

1. Make remote command-line work practical on a phone.
2. Remove repetitive SSH setup and command typing.
3. Make projects, remote sessions and common actions directly accessible.
4. Preserve long-running work across mobile network interruptions.
5. Support real SSH rather than a proprietary remote-control protocol.
6. Work on Android and iOS from one main codebase.
7. Keep all critical user data local by default.
8. Provide strong key and host-verification security.
9. Be usable by both developers and technically capable server users.
10. Remain useful without requiring any RelayShell server account.

### 2.2 Non-goals

The application will **not** initially attempt to be:

- a local Linux distribution such as Termux;
- a Docker runtime on the phone;
- a graphical Remote Desktop / VNC client;
- a cloud IDE;
- a GitHub/GitLab replacement;
- a team collaboration platform;
- a remote management SaaS;
- a proprietary relay/VPN service;
- a full text editor or VS Code replacement.

These can be integrated externally through SSH, port forwarding or browser links where appropriate.

---

## 3. Target Users

### 3.1 Developer

Needs to:

- enter a project quickly;
- run Git commands;
- use Codex, Claude Code, Gemini CLI, shell scripts or build tools;
- resume tmux sessions;
- inspect logs;
- restart development services;
- make small emergency fixes remotely.

### 3.2 Server / Homelab user

Needs to:

- SSH into servers;
- inspect CPU, memory, disk and services;
- restart Docker containers;
- browse files;
- run maintenance commands;
- maintain multiple machines.

### 3.3 Power user

Needs a better mobile interface for SSH without learning or configuring a full mobile Linux environment.

---

## 4. Product Principles

### 4.1 Mobile-first, not desktop-terminal-shrunk-to-phone

Frequent operations should require taps rather than typing.

### 4.2 Direct connection

Whenever possible:

```text
Mobile App → SSH → User Computer
```

No RelayShell cloud service is required for terminal traffic.

### 4.3 Session persistence

Long-running work should normally run inside tmux on the remote computer.

### 4.4 Local-first data

Hosts, projects, snippets and app settings stay on-device by default.

### 4.5 Explicit security

New SSH host keys, changed fingerprints and dangerous commands must never be silently accepted.

### 4.6 Progressive power

A new user can add one computer and tap Terminal. Advanced users can later add projects, tmux sessions, port forwarding, keys and command actions.

---

## 5. Platform Scope

### Supported

- Android phones and tablets
- iPhone
- iPad

The initial interface should prioritize portrait phone use while supporting landscape and larger screens.

### Remote operating systems

Any system exposing a compatible SSH server, including:

- Linux
- macOS
- Windows with OpenSSH Server
- BSD
- NAS appliances
- VPS / cloud servers
- routers or embedded Linux where SSH is available

Remote features such as tmux or specific saved actions may require software installed on the remote machine.

---

# 6. Information Architecture

Primary navigation:

```text
Home
Computers
Projects
Sessions
More
```

`More` contains:

```text
Commands
Keys
Port Forwarding
Settings
About
```

On tablets, the same sections may use a navigation rail rather than bottom navigation.

---

# 7. Home Screen

The Home screen is an action dashboard, not a terminal.

## 7.1 Sections

### Continue

Shows recently active terminal/tmux sessions.

Example:

```text
Continue

● GoByBus — Codex
  Home PC · tmux
  Last used 8 min ago
  [Resume]

● Server Logs
  VPS
  Last used yesterday
  [Resume]
```

### Computers

Shows pinned or recently used computers.

Each card displays:

- name;
- optional icon/color;
- hostname/IP;
- last known connection status;
- last connected time;
- Connect button;
- Files shortcut;
- overflow menu.

### Projects

Shows pinned/recent projects.

Each card contains:

- project name;
- associated host;
- remote directory;
- terminal shortcut;
- configured actions.

### Quick Actions

Shows user-selected commands such as:

- Git Status
- Git Pull
- Docker PS
- Restart App
- Disk Usage
- System Status

## 7.2 Connection-status behavior

The UI may show:

- Unknown
- Checking
- Reachable
- Unreachable

Status is advisory only. The application must not continuously scan hosts in the background.

A failed reachability check must not prevent the user from attempting SSH.

---

# 8. Computers / Hosts

A Computer represents one SSH destination.

## 8.1 Host fields

```text
id
name
hostname
port
username
authentication_method
credential_id
startup_directory (optional)
environment_notes (optional)
color/icon (optional)
favorite
created_at
updated_at
last_connected_at
```

Default port: `22`.

## 8.2 Authentication methods

Support:

1. SSH private key
2. Password
3. Keyboard-interactive
4. SSH agent / external signer where platform support is available

Password authentication is supported but key authentication should be recommended.

## 8.3 Host creation flow

```text
Add Computer
    ↓
Name
Hostname / IP
Port
Username
    ↓
Authentication
    ↓
Test Connection
    ↓
Verify Host Fingerprint
    ↓
Save
```

`Test Connection` is optional; users may save without testing.

## 8.4 Editing

Changing hostname or port does not silently reuse a trusted host fingerprint without validation.

If the host identity changes, the next connection must perform host verification again.

## 8.5 Host actions

From the Computer detail screen:

- Open Terminal
- Resume Session
- Files
- Projects
- Run Command
- Port Forwarding
- Edit
- Duplicate
- Delete

---

# 9. SSH Connection Model

## 9.1 Connection states

```text
idle
resolving
connecting
handshaking
verifying_host
authenticating
connected
reconnecting
failed
closed
```

The UI should translate these into user-readable states.

## 9.2 Host key verification

First connection:

1. Receive server host fingerprint.
2. Display hostname, key type and SHA-256 fingerprint.
3. User chooses Trust / Cancel.
4. Save trusted fingerprint.

Later connections:

- matching fingerprint → connect normally;
- changed fingerprint → block connection and show a prominent warning.

The app must never provide a global default of silently disabling host-key verification.

## 9.3 Keepalive

SSH keepalive should be configurable with a sensible default.

The connection manager should detect:

- network change;
- socket loss;
- app lifecycle interruption;
- SSH timeout.

## 9.4 Reconnect

When a connection drops:

```text
Connection lost
[Reconnect]
```

If the terminal was attached to a managed tmux session:

```text
Reconnect
   ↓
SSH login
   ↓
Reattach tmux
   ↓
Return to same session
```

Automatic reconnection may occur for a short bounded period, but must stop after repeated failure.

No infinite aggressive retry loop.

---

# 10. Terminal

The terminal is a full interactive SSH PTY.

## 10.1 Required behavior

Support:

- UTF-8;
- ANSI colors;
- standard VT/xterm sequences;
- resize events;
- Unicode;
- CJK;
- emoji where terminal/font permits;
- copy;
- paste;
- selection;
- scrollback;
- search in visible/scrollback terminal text;
- landscape mode;
- external keyboards;
- IME input.

## 10.2 Terminal header

Example:

```text
←  GoByBus / Home PC          ⋮
   tmux: gobybus-codex
```

Header menu:

- Session Info
- Reconnect
- Send Command
- Open Files Here
- Change Font Size
- Toggle Keep Screen On
- Disconnect

## 10.3 Mobile accessory keyboard row

Default row:

```text
ESC   CTRL   ALT   TAB   ↑
                     ←   ↓   →
```

Second configurable row may contain:

```text
|   ~   /   -   _   :   CTRL+C
```

Users can customize the keys shown.

## 10.4 Control keys

Buttons such as `CTRL` and `ALT` support:

- tap once → apply to next key;
- long press → lock modifier;
- visible active state.

Provide direct actions for common combinations:

- Ctrl+C
- Ctrl+D
- Ctrl+L
- Ctrl+R
- Ctrl+Z

## 10.5 Gestures

Default:

- vertical swipe → terminal scrollback;
- pinch → font-size adjustment optional;
- long press → selection/context menu.

Avoid gestures that conflict with ordinary terminal applications.

## 10.6 Terminal tabs

The app supports multiple active terminals.

A terminal switcher should show:

```text
Home PC · shell
GoByBus · Codex
VPS · logs
```

Tabs do not imply all network connections must stay alive indefinitely.

---

# 11. Sessions and tmux

tmux support is a product-level feature rather than a hidden terminal trick.

## 11.1 Two session types

### Direct session

Normal SSH shell.

If disconnected, the remote shell may terminate.

### Persistent session

SSH terminal attached to a tmux session.

Recommended for long-running activity.

## 11.2 Managed tmux sessions

The app can create predictable session names.

Example:

```text
rdc-gobybus-codex
rdc-home-shell
rdc-server-logs
```

The exact prefix is internal/configurable and should avoid collisions.

## 11.3 Session operations

- Create
- Attach
- Detach
- Resume
- Rename
- Kill
- List

## 11.4 tmux discovery

When requested, run a safe command equivalent to listing tmux sessions and parse the result.

If `tmux` is unavailable:

```text
tmux is not installed on this computer.

[Use direct terminal]
```

The app must not automatically install packages on the remote system.

## 11.5 Resume model

Each managed session record stores:

```text
host_id
project_id (optional)
tmux_session_name
display_name
working_directory
last_used_at
launch_action_id (optional)
```

The actual process state remains on the remote computer; the app only stores the information required to reconnect.

---

# 12. Projects

Projects are the primary abstraction that differentiates the app from a generic SSH client.

## 12.1 Project fields

```text
id
name
host_id
remote_path
description (optional)
default_session_mode
default_tmux_name (optional)
favorite
created_at
updated_at
last_opened_at
```

## 12.2 Project detail

Example:

```text
GoByBus

Home PC
~/projects/Go_by_Bus_HK

[Open Terminal]

ACTIONS
[Codex]
[Git Status]
[Git Pull]
[Start Dev Server]

FILES
[Browse Project]
```

## 12.3 Opening a project

The app must avoid string-concatenating unsafe shell commands.

Conceptually:

```text
SSH PTY
   ↓
change to configured working directory
   ↓
open shell or attach/create tmux
```

Paths must be correctly shell-escaped when commands are generated.

## 12.4 Project actions

Actions can be:

### Interactive

Example:

```text
codex
claude
npm run dev
```

Runs in an interactive terminal.

### One-shot

Example:

```text
git status
df -h
docker compose ps
```

Can display output in a compact result screen with an option to open the full terminal.

---

# 13. Commands / Actions

Saved Commands provide tap-based access to frequently used commands.

## 13.1 Command fields

```text
id
name
command
scope
host_id (optional)
project_id (optional)
working_directory (optional)
execution_mode
confirmation_mode
favorite
created_at
updated_at
```

Scopes:

- Global
- Computer
- Project

Execution modes:

- Interactive terminal
- One-shot command

Confirmation modes:

- None
- Always confirm
- Dangerous command confirmation

## 13.2 Command variables

Support simple variables:

```text
{{project_path}}
{{host_name}}
{{input:name}}
```

`{{input:name}}` prompts the user before execution.

Do not implement a general scripting/template programming language.

## 13.3 Dangerous commands

The application cannot reliably determine whether every shell command is dangerous.

Provide:

- manual `Require confirmation` flag;
- additional warning for obvious destructive patterns where practical;
- preview of the final command before confirmed execution.

Never claim that the safety detector guarantees a command is safe.

---

# 14. AI CLI Launchers

AI CLIs are treated as ordinary configurable project actions with convenient presets.

Built-in templates may include:

- Codex
- Claude Code
- Gemini CLI
- Custom CLI

Example launcher configuration:

```text
Name: Codex
Command: codex
Mode: Interactive
Session: Persistent tmux
Working directory: Project directory
```

The app does **not** embed or proxy the AI model.

Credentials and authentication remain on the remote computer.

This avoids duplicating provider login/token management inside the mobile app.

---

# 15. Remote Files

Files use SFTP over the selected SSH connection.

## 15.1 Browser

Display:

- folders;
- files;
- symlinks where supported;
- file size;
- modified time.

Operations:

- navigate;
- refresh;
- upload;
- download;
- rename;
- move;
- create folder;
- delete;
- copy path;
- open small text file;
- share/download to device.

## 15.2 File safety

Delete operations require confirmation.

For directory deletion, clearly identify whether deletion is recursive.

## 15.3 File viewer

Built-in read-only viewer for reasonable-sized:

- plain text;
- JSON;
- YAML;
- Markdown;
- logs;
- source code.

A lightweight text edit/save function may be provided for small files.

The app is not intended to become a full IDE/editor.

## 15.4 Large files

Large uploads/downloads must show:

- progress;
- transferred bytes;
- cancel action;
- clear failure state.

Do not load large files completely into UI memory.

---

# 16. Port Forwarding

Support SSH forwarding as an advanced feature.

Types:

- Local forwarding
- Remote forwarding
- Dynamic SOCKS forwarding, where supported

Example local-forward use:

```text
Phone localhost:8080
        ↓ SSH
Remote localhost:3000
```

The app should show active forwards and allow stopping them.

This feature belongs under advanced tools and should not complicate the main UI.

---

# 17. Wake-on-LAN

Optional per-host configuration:

```text
MAC address
broadcast address
port
```

If configured, a `Wake` action can appear on the host card.

Wake-on-LAN is best-effort; the app must not imply the machine is guaranteed to wake over arbitrary external networks.

---

# 18. Credentials and SSH Keys

## 18.1 Key management

Users can:

- import private key;
- generate supported key type;
- name key;
- associate key with one or more computers;
- view public key;
- copy public key;
- delete key.

The private key itself must not be displayed casually after import.

## 18.2 Secret storage

Sensitive material must use platform secure storage.

Sensitive:

- private keys;
- passwords;
- private-key passphrases;
- optional app unlock secret.

Non-sensitive configuration may remain in the application database.

## 18.3 Biometrics

Optional setting:

```text
Require biometric/device authentication
before using protected credentials
```

Behavior must follow platform capabilities.

Biometrics are an additional access control, not a substitute for SSH authentication.

---

# 19. App Lock

Optional:

- biometric;
- device credential where supported;
- lock immediately;
- after 1 minute;
- after 5 minutes;
- after 15 minutes.

When locked, sensitive terminal content should not be intentionally exposed in app previews where platform APIs allow protection.

---

# 20. Search

One app-wide search can search local metadata:

- computers;
- projects;
- saved commands;
- sessions.

Do not remotely crawl server file systems for global search.

---

# 21. Settings

## Appearance

- System / Light / Dark
- Terminal theme
- Terminal font
- Font size
- Cursor style
- Haptic feedback
- Keep screen awake while terminal is active

## Terminal

- Scrollback limit
- Accessory key layout
- Copy-on-select toggle
- Paste confirmation for multiline text
- Default shell/session mode

## SSH

- Keepalive interval
- Connection timeout
- Authentication timeout
- Default terminal type
- Reconnect behavior

## Security

- App lock
- Credential biometric protection
- Trusted host fingerprints
- Clear clipboard after copied secrets where practical

## Data

- Export configuration
- Import configuration
- Reset app

---

# 22. Import / Export

Users should be able to back up app configuration without requiring a cloud account.

Export may contain:

- hosts;
- projects;
- saved commands;
- UI preferences;
- tmux session metadata.

Credentials/private keys are excluded by default.

An advanced encrypted backup option may include credentials only when protected by a user-supplied backup passphrase.

Never export private keys into an unencrypted configuration file.

---

# 23. Data Model

Recommended local relational model:

```text
hosts
credentials
trusted_host_keys
projects
commands
terminal_profiles
session_records
port_forward_profiles
wol_profiles
app_preferences
recent_items
```

## 23.1 Relationships

```text
Host
 ├── Credential
 ├── TrustedHostKey
 ├── Projects[]
 ├── Commands[]
 ├── Sessions[]
 ├── ForwardProfiles[]
 └── WoLProfile?

Project
 ├── Host
 ├── Commands[]
 └── Sessions[]
```

## 23.2 Sensitive-data boundary

Database stores references such as:

```text
credential_id = "cred_123"
```

Actual secret material is stored separately in platform secure storage.

---

# 24. Application Architecture

Use a pragmatic layered Flutter application.

```text
lib/
├── app/
│   ├── router/
│   ├── theme/
│   └── app.dart
│
├── features/
│   ├── home/
│   ├── hosts/
│   ├── terminal/
│   ├── projects/
│   ├── sessions/
│   ├── commands/
│   ├── files/
│   ├── keys/
│   ├── forwarding/
│   └── settings/
│
├── core/
│   ├── ssh/
│   ├── storage/
│   ├── security/
│   ├── database/
│   ├── shell/
│   └── platform/
│
└── shared/
    ├── widgets/
    ├── models/
    └── utilities/
```

Avoid creating independent services/microservices.

---

# 25. Recommended Technical Stack

## Application

- Flutter / Dart

## SSH / SFTP

- `dartssh2` or equivalent maintained SSH implementation

Required capabilities:

- SSH authentication;
- interactive sessions;
- PTY;
- SFTP;
- forwarding;
- host-key verification hooks;
- timeouts;
- key identities.

## Terminal renderer

- `xterm` or equivalent permissively licensed Flutter terminal implementation.

The selected terminal component must be validated against:

- CJK;
- IME;
- ANSI;
- vim/nvim;
- tmux;
- interactive AI CLI applications;
- external keyboard;
- performance on older Android devices.

## Local database

- SQLite through Drift or an equivalent typed persistence layer.

## Secure storage

- iOS Keychain
- Android platform-backed secure storage / Keystore integration

A Flutter secure-storage wrapper may be used.

## Navigation

- Flutter declarative routing such as `go_router`, or a similarly maintained solution.

The project should avoid unnecessary custom framework layers around these packages.

---

# 26. State Management

Use one consistent Flutter state-management approach.

Requirements:

- feature-level state;
- connection state streams;
- terminal/session state;
- database-backed reactive state;
- lifecycle handling.

The exact library is less important than consistency.

Do not combine several state frameworks without a concrete reason.

---

# 27. SSH Core Service

The SSH layer should expose domain-level operations rather than leaking library objects throughout the UI.

Conceptual interface:

```text
connect(host)
disconnect(connectionId)
openShell(connectionId, ptyOptions)
execute(connectionId, command)
openSftp(connectionId)
createLocalForward(...)
createRemoteForward(...)
listTmuxSessions(...)
attachTmux(...)
```

The SSH core owns:

- connection establishment;
- host verification;
- authentication;
- keepalive;
- connection teardown;
- errors;
- reconnect coordination.

---

# 28. Connection Lifecycle

Mobile OS background restrictions mean the app must assume sockets can disappear.

Design rule:

> Remote process persistence must not depend on the mobile TCP connection.

For important work, tmux provides persistence on the remote machine.

When app state changes:

### Foreground → background

- retain connection where OS permits;
- do not assume it will survive;
- save local session metadata.

### Background → foreground

- check connection;
- if dead, show reconnect;
- managed tmux sessions may automatically reattach after successful reconnect.

Do not attempt hacks that keep the app permanently alive in the background.

---

# 29. Shell Command Construction

Any internally generated shell command must:

- quote paths safely;
- avoid direct unescaped string interpolation;
- use the selected remote shell assumptions explicitly.

The app should default to POSIX-compatible shell behavior for Linux/macOS.

Windows-specific handling must be separated where command semantics differ.

User-entered saved commands are considered intentional shell input and are sent as configured.

---

# 30. Windows Support

Windows OpenSSH should support:

- normal terminal;
- PowerShell/cmd depending on server configuration;
- SFTP;
- SSH authentication.

Unix-only features such as tmux must be hidden or marked unavailable when not present.

Project paths and generated commands must account for Windows path/shell differences rather than assuming `/home/user`.

---

# 31. Error Handling

Errors must be actionable.

Examples:

### DNS failure

```text
Cannot find this computer.
Check the hostname or network connection.
```

### Connection refused

```text
SSH connection refused on port 22.
Check that SSH Server is running and the port is correct.
```

### Authentication failure

```text
Authentication failed.
[Change Credential]
[Try Again]
```

### Host key changed

```text
WARNING
The SSH identity of this computer has changed.

Saved:
SHA256:...

Received:
SHA256:...

Connection has been blocked.
```

### tmux unavailable

Explain the feature dependency and allow direct shell use.

Raw exceptions may be available under a technical-details expander but should not be the primary message.

---

# 32. Empty States

Every major screen requires a useful empty state.

Example Computers:

```text
No computers yet

Add a computer that you can access through SSH.

[Add Computer]
```

Example Projects:

```text
No projects yet

A project links a remote folder with terminal sessions
and reusable actions.

[Add Project]
```

---

# 33. Permissions

Request only when needed.

Possible permissions/capabilities:

- network access;
- local file picker / document access for key import and transfers;
- biometric capability;
- notifications only if a concrete notification feature requires them.

Do not request contacts, location, microphone, camera or phone permissions without a defined feature.

---

# 34. Privacy

Default architecture contains no product account and no remote terminal proxy.

The app should not collect:

- terminal content;
- remote commands;
- private keys;
- passwords;
- remote file contents.

If crash reporting or product analytics are added, they must explicitly exclude sensitive terminal/session data.

A privacy setting should allow analytics to be disabled if analytics are used.

---

# 35. Logging

Application logs may contain:

- connection state;
- timing;
- non-sensitive error codes;
- package/app version;
- anonymized internal identifiers.

Logs must not contain:

- passwords;
- private key data;
- passphrases;
- terminal output by default;
- full commands by default;
- remote file contents.

Debug builds may provide additional developer diagnostics with explicit safeguards.

---

# 36. Performance Requirements

The app should remain usable on older but supported devices.

Targets:

- terminal typing should feel immediate;
- terminal rendering should maintain smooth scrolling under normal output;
- SSH negotiation must not block the Flutter UI thread;
- large SFTP transfers must stream;
- terminal scrollback must have a bounded configurable limit;
- inactive connections should not consume excessive battery;
- Home must not initiate dozens of simultaneous network checks.

---

# 37. Accessibility

Support:

- system font scaling where compatible;
- sufficient color contrast;
- semantic labels for buttons;
- screen reader labels outside raw terminal content;
- buttons not distinguished by color alone;
- landscape mode;
- external keyboard navigation where practical.

Terminal font size remains independently configurable.

---

# 38. Localization

UI strings should be localization-ready from the start.

Initial languages can be selected based on release needs, but architecture should not hard-code English text directly into widgets.

Terminal content is never translated.

---

# 39. Design System

Style should feel like a modern utility rather than a hacker-themed novelty.

## Visual principles

- dark mode first-class, not mandatory;
- simple surfaces;
- high information density without clutter;
- one clear primary action per card;
- status colors used semantically;
- terminal visually separated from app navigation.

Suggested semantic states:

```text
Connected
Connecting
Warning
Error
Inactive
```

Avoid excessive gradients, decorative animations, glass effects or oversized cards.

---

# 40. Main User Flows

## 40.1 First computer

```text
Launch
 ↓
Add Computer
 ↓
Enter SSH details
 ↓
Choose credential
 ↓
Connect
 ↓
Verify fingerprint
 ↓
Terminal
```

## 40.2 Create project

```text
Computer
 ↓
Add Project
 ↓
Name + Remote Path
 ↓
Choose direct/tmux default
 ↓
Save
 ↓
Project Dashboard
```

## 40.3 Launch Codex

```text
Home
 ↓
GoByBus
 ↓
Codex
 ↓
SSH Connect
 ↓
cd project
 ↓
Attach/Create tmux
 ↓
Run codex
 ↓
Interactive Terminal
```

## 40.4 Recover after disconnect

```text
Network Lost
 ↓
Terminal shows disconnected
 ↓
Reconnect
 ↓
SSH Auth
 ↓
Reattach tmux
 ↓
Continue existing work
```

## 40.5 Browse project files

```text
Project
 ↓
Files
 ↓
SFTP open project path
 ↓
Browse / Download / Edit small file
```

---

# 41. App Startup

Startup should:

1. initialize secure storage/database;
2. restore preferences;
3. show the Home screen quickly;
4. load local recents;
5. optionally refresh a small number of visible host statuses.

Do not reconnect every historic SSH session automatically at app launch.

Managed sessions should appear as resumable metadata until opened.

---

# 42. Notifications

Notifications are not required for normal terminal operation.

Possible future/optional use:

- completion notification for an explicitly launched long-running one-shot action;
- transfer completed;
- transfer failed.

Do not implement a remote monitoring notification service without a separate product requirement.

---

# 43. Testing Strategy

## Unit tests

Cover:

- shell/path escaping;
- host fingerprint matching;
- connection state transitions;
- project/session command construction;
- tmux-name generation;
- command variable substitution;
- database migrations;
- settings;
- sensitive-data redaction.

## Integration tests

Test against real SSH environments:

- Ubuntu/OpenSSH;
- macOS SSH;
- Windows OpenSSH;
- password auth;
- key auth;
- key with passphrase;
- incorrect key;
- changed host key;
- high latency;
- dropped network;
- SFTP transfer;
- port forwarding.

## Terminal compatibility tests

Test:

- bash/zsh;
- PowerShell where supported;
- vim;
- nvim;
- tmux;
- htop;
- git;
- less;
- interactive prompts;
- Codex;
- Claude Code where available;
- rapid log output;
- Unicode/CJK.

## Device tests

At minimum:

- older supported Android phone;
- current Android phone;
- iPhone;
- iPad/tablet layout;
- Bluetooth keyboard.

---

# 44. Security Acceptance Requirements

Release must not ship if any of these fail:

1. Private keys are stored in plain SQLite.
2. Passwords appear in application logs.
3. Host-key changes are silently accepted.
4. Export can leak unencrypted private credentials by default.
5. Terminal history/output is uploaded to analytics.
6. Credentials are included in crash reports.
7. Debug SSH logging containing secrets is enabled in production.
8. The app disables SSH verification globally for convenience.

---

# 45. Functional Completion Criteria

The app is considered functionally complete when a user can:

- maintain multiple SSH computers;
- securely manage credentials;
- verify SSH host identities;
- open concurrent interactive terminals;
- use a mobile terminal keyboard comfortably;
- create project shortcuts;
- open a project directly at its remote path;
- define and execute reusable actions;
- run interactive project tools;
- discover/create/resume tmux sessions;
- recover from mobile connection loss;
- browse and transfer files using SFTP;
- use supported SSH port forwarding;
- export/import non-secret configuration;
- configure appearance, keyboard, SSH and security behavior;
- use the major flows on both Android and iOS.

This definition intentionally covers the complete planned application rather than only a launch MVP.

---

# 46. Development Order

The specification is complete-app scope, but implementation should still be staged to reduce technical risk.

## Stage 1 — Core transport

- Flutter shell
- local database
- secure storage
- host management
- SSH authentication
- host-key verification
- interactive PTY
- terminal renderer

## Stage 2 — Mobile terminal quality

- accessory keys
- copy/paste
- resizing
- scrollback
- multiple sessions
- reconnect handling
- lifecycle tests

## Stage 3 — Product abstractions

- Projects
- saved Commands
- action launcher
- recent/pinned Home
- session metadata

## Stage 4 — Persistent workflow

- tmux detection
- managed sessions
- reconnect + reattach
- AI CLI presets

## Stage 5 — Remote files and advanced SSH

- SFTP browser
- transfers
- small text viewer/editor
- port forwarding
- Wake-on-LAN

## Stage 6 — Production hardening

- app lock/biometrics
- import/export
- localization framework
- accessibility
- performance tuning
- device compatibility
- store privacy material
- release testing

These stages are implementation order only. They do not redefine the product as an MVP.

---

# 47. Explicitly Deferred Features

The following should require a new product decision rather than quietly expanding the architecture:

- RelayShell user accounts
- proprietary backend
- cloud credential sync
- team sharing
- remote desktop
- server fleet monitoring
- hosted relay/VPN
- web dashboard
- billing/subscriptions
- plugin marketplace
- embedded AI-provider API gateway

The current architecture should not prevent future expansion, but it should not pre-build infrastructure for these hypothetical features.

---

# 48. Product Definition

RelayShell should be judged by this question:

> Can a user take out a phone, reach the correct computer/project/session, perform useful development or server work with minimal typing, put the phone away, and later continue safely?

If yes, the product is doing its job.

The final experience should feel closer to a **mobile control center for remote development** than either:

- a local Linux emulator, or
- a generic blank-screen SSH client.
