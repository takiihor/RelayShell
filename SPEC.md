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

RelayShell also provides **Conversation Mode**: a chat-shaped, mobile-first view of a real remote shell. Conversation Mode is not an AI chatbot and does not translate natural language. The user enters actual shell commands, and RelayShell sends them directly through SSH to a clean remote PTY. While Herdr, Codex, Claude Code, Pi, or another interactive process is running, the same composer can send stdin to that foreground process and the mobile accessory row can send exact terminal-control sequences such as Ctrl, Shift, Alt, Tab, ESC, arrows, and `/`. Normal Conversation Mode operation uses no LLM tokens.

The detailed Conversation Mode UX, framing protocol, Herdr/coding-agent behavior, fallback rules and acceptance criteria are defined in [design.md](design.md).

---

## 2. Product Goals

### 2.1 Primary goals

1. Make remote command-line work practical on a phone.
2. Remove repetitive SSH setup and command typing.
3. Make projects, remote sessions and common actions directly accessible.
4. Preserve long-running work across mobile network interruptions where the selected remote tool/session supports persistence.
5. Support real SSH rather than a proprietary remote-control protocol.
6. Work on Android and iOS from one main codebase.
7. Keep all critical user data local by default.
8. Provide strong key and host-verification security.
9. Be usable by both developers and technically capable server users.
10. Remain useful without requiring any RelayShell server account.
11. Provide a command-first Conversation Mode that keeps ordinary terminal use token-free.
12. Make interactive coding-agent workflows practical on mobile by preserving real PTY stdin and terminal key semantics.

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
- a full text editor or VS Code replacement;
- an AI chatbot that places an LLM between the user and every shell command.

Optional AI assistance can be added later only as an explicit, opt-in action that is separate from the normal shell path.

---

## 3. Target Users

### 3.1 Developer

Needs to:

- enter a project quickly;
- run Git commands;
- use Codex, Claude Code, Gemini CLI, Pi, Herdr, shell scripts or build tools;
- resume tmux/Herdr sessions;
- inspect logs;
- restart development services;
- make small emergency fixes remotely;
- use Ctrl/Shift/Alt/Tab/ESC/arrow/symbol keys comfortably from a phone;
- send conversational stdin to a running coding agent without switching apps.

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

Frequent operations should require taps rather than typing. Conversation Mode should make normal shell commands easy to read and re-use, while the full Terminal remains immediately available for TUIs and exact screen rendering.

### 4.2 Direct connection

Whenever possible:

```text
Mobile App → SSH → User Computer
```

No RelayShell cloud service is required for terminal traffic.

### 4.3 Honest session persistence

Long-running work should use tmux/Herdr or another explicit remote persistence mechanism. RelayShell must not claim that a direct shell process survived when its SSH/PTTY session ended.

Conversation Mode deliberately starts from a clean direct shell so its framing protocol cannot be injected into an existing Herdr/tmux TUI. If the user launches Herdr inside Conversation Mode, Herdr's own remote persistence remains available according to Herdr's behavior.

### 4.4 Local-first data

Hosts, projects, snippets and app settings stay on-device by default. Conversation presentation history is local; the first implementation keeps it in memory only.

### 4.5 Explicit security

New SSH host keys, changed fingerprints and dangerous saved commands must never be silently accepted.

### 4.6 Progressive power

A new user can add one computer and tap Shell or Terminal. Advanced users can later add projects, tmux/Herdr sessions, port forwarding, keys and command actions.

### 4.7 Real terminal semantics for coding agents

RelayShell must not replace terminal keys with textual approximations. Interactive tools receive real PTY bytes. Mobile modifier keys may arm or lock and combine with accessory keys or the next soft-keyboard character where practical. Conversation and Terminal Mode reuse the same input semantics.

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

Conversation Mode framing initially targets POSIX shells. Windows remains fully supported through Terminal Mode while a PowerShell-specific Conversation framing protocol is designed and tested.

Remote features such as tmux, Herdr or specific saved actions may require software installed on the remote machine.

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

Computer and Project detail surfaces expose both:

```text
[Shell]      Conversation Mode for POSIX hosts
[Terminal]   Full terminal
```

Terminal remains the fallback for unsupported shells and full-screen TUIs.

---

# 7. Home Screen

The Home screen is an action dashboard, not a terminal.

## 7.1 Sections

### Continue

Shows recently active terminal/tmux/Herdr sessions.

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
- Shell/Terminal shortcut;
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

Reachability status is advisory. A failed probe must never prevent an actual SSH connection attempt.

---

# 8. Computers

## 8.1 Computer fields

A computer stores the information required to reach and describe one SSH endpoint, including hostname/IP, port, username, authentication metadata, remote shell family, optional startup directory, preferred multiplexer, display metadata and optional Wake-on-LAN information.

Secrets are never stored in the normal application database.

## 8.2 Add / edit flow

Conceptually:

```text
Computer details
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

## 8.3 Host identity

Changing hostname or port does not silently reuse a trusted host fingerprint without validation.

If the host identity changes, the next connection must perform host verification again.

## 8.4 Computer actions

From the Computer detail screen:

- Open Shell / Conversation Mode (POSIX)
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

## 9.3 Shared transport

One live SSH transport per host is shared by terminal channels, Conversation channels, SFTP and forwarding where practical.

Conversation Mode gets its own clean shell channel, not its own SSH authentication stack or relay service.

## 9.4 Keepalive

SSH keepalive should be configurable with a sensible default.

The connection manager should detect:

- network change;
- socket loss;
- app lifecycle interruption;
- SSH timeout.

## 9.5 Reconnect

When a connection drops:

```text
Connection lost
[Reconnect]
```

If the terminal was attached to a managed persistent session:

```text
Reconnect
   ↓
SSH login
   ↓
Reattach multiplexer
   ↓
Return to same session
```

A direct Conversation shell cannot promise that its foreground process survives a transport loss. It must mark an active command disconnected rather than inventing continuity.

Automatic reconnection may occur for a short bounded period, but must stop after repeated failure. No infinite aggressive retry loop.

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

Default coding-oriented rows include:

```text
ESC   CTRL   SHIFT   ALT   TAB   ↑   ←   ↓   →
SCRL↑ SCRL↓ / ~ | & - _ : ^C
```

Users can customize the keys shown.

## 10.4 Control and modifier keys

`CTRL`, `ALT` and `SHIFT` support:

- tap once → apply to next key;
- long press → lock modifier;
- visible active state;
- visible lock state.

Required sequences include:

- Ctrl+C / D / L / R / Z;
- Shift+Tab as xterm back-tab;
- Shift+arrow with xterm modifier parameter 2;
- Shift plus common punctuation such as `/` → `?`.

Where a single character from the phone soft keyboard can be safely identified, an armed modifier may transform that next character, e.g. CTRL then `b` → Ctrl+B.

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

# 11. Conversation Mode

The normative detailed design is [design.md](design.md). The requirements below summarize product-level behavior.

## 11.1 Shell framing

Conversation Mode starts a clean direct POSIX shell/PTTY and uses private random BEGIN/END markers to frame one user shell command at a time without parsing PS1.

Framing must preserve shell state (`cd`, `export`, environment activation) and must never queue RelayShell footer/status lines where an interactive child can consume them as stdin.

## 11.2 Conversation command state

Each shell command tracks:

```text
command
running/completed/interrupted/disconnected
streamed output
exit code
elapsed time
truncation state
interactive/full-screen hints
human process-input messages
```

Output is bounded in memory and common ANSI control sequences are removed from the text representation.

## 11.3 Interactive process mode

When a command remains active, the Conversation composer sends subsequent human text to that foreground process stdin instead of starting another framed shell command.

Examples:

```text
herdr ...
codex
claude
pi
ctxguard
ssh other-host
```

Accessory keys send exact PTY bytes and are not recorded as chat messages.

## 11.4 Herdr-friendly controls

Conversation Mode renders one horizontally scrolling compact accessory row and guarantees:

```text
ESC CTRL SHIFT ALT TAB /
```

User-configured arrows, symbols, Ctrl shortcuts and scroll keys are appended without duplicates.

Ctrl/Alt/Shift may be armed or locked. While a foreground interactive process is active, an armed modifier can also transform the next identifiable single soft-keyboard character.

## 11.5 Full-screen fallback

Conversation Mode detects common alternate-screen enable sequences. When a command becomes a full-screen TUI, the UI prominently offers `Open in terminal`.

The Terminal screen must use the **same live TerminalSession/PTTY**. It must not restart Herdr, Codex, vim, or any other foreground process.

---

# 12. Sessions and multiplexers

Multiplexer support is a product-level feature rather than a hidden terminal trick.

## 12.1 Two terminal session types

### Direct session

Normal SSH shell. If disconnected, the remote foreground process may terminate.

### Persistent session

SSH terminal attached to a supported persistent backend such as tmux or Herdr.

Recommended for long-running work that needs remote persistence.

Conversation Mode currently uses a clean direct shell for framing safety; persistence of a Herdr session launched inside it follows Herdr's own behavior.

## 12.2 Managed sessions

The app can create predictable managed session names.

Example:

```text
rdc-gobybus-codex
rdc-home-shell
rdc-server-logs
```

## 12.3 Session operations

- Create
- Attach
- Detach
- Resume
- Rename where backend supports it
- Kill
- List

## 12.4 Discovery

When requested, run a safe machine-readable session-list command appropriate to the configured backend.

If the backend is unavailable, explain the missing executable and offer a direct terminal rather than automatically installing packages.

## 12.5 Resume model

Each managed session record stores the local information required to reconnect/reattach. The actual process state remains on the remote computer.

---

# 13. Projects

Projects are the primary abstraction that differentiates the app from a generic SSH client.

## 13.1 Project fields

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

## 13.2 Project detail

Example:

```text
GoByBus

Home PC
~/projects/Go_by_Bus_HK

[Shell] [Terminal]

ACTIONS
[Codex]
[Git Status]
[Git Pull]
[Start Dev Server]

FILES
[Browse Project]
```

## 13.3 Opening a project

Generated path commands must be correctly shell-escaped. Conversation Mode opens its clean direct shell at the configured project path; Terminal Mode follows the requested direct/persistent session policy.

## 13.4 Project actions

Actions can be interactive or one-shot. Interactive actions normally open Terminal Mode unless explicitly designed for Conversation process-input behavior.

---

# 14. Commands / Actions

Saved Commands provide tap-based access to frequently used commands.

## 14.1 Command fields

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

## 14.2 Command variables

Support simple variables such as project path, host name and explicitly requested input values. Do not implement a general scripting/template programming language.

## 14.3 Dangerous commands

The application cannot reliably determine whether every shell command is dangerous.

Provide preview and confirmation rules for saved commands. Raw commands typed directly into a live shell/Conversation are intentional user input and should not be silently rewritten or blocked by a simplistic detector.

---

# 15. AI CLI Launchers

AI CLIs are ordinary configurable remote programs from RelayShell's perspective.

Examples:

```text
codex
claude
gemini
pi
herdr
```

RelayShell does not proxy their model traffic. Authentication and model/API usage belong to the CLI running on the remote computer.

Conversation Mode may provide stdin and terminal controls to a running CLI, but it does not itself become an LLM client.

---

# 16. Files, forwarding, settings and remaining product areas

Existing SFTP, port-forwarding, key management, settings, import/export, accessibility, localization, security and release requirements remain in force. Conversation Mode must integrate without weakening those existing boundaries.

---

# 17. Testing and release gates

Pull requests must run:

```bash
flutter analyze
flutter test
```

Conversation-specific automated tests include real `/bin/sh` framing tests for persistent state and interactive stdin/footer isolation, plus modifier/accessory-key tests.

Physical Android/iOS release verification follows [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md), including Herdr/coding-agent input, soft-keyboard modifier behavior, alternate-screen fallback and same-PTY Terminal switching.

Automated tests do not replace physical-device verification of mobile keyboards, OS prompts or real SSH interoperability.
