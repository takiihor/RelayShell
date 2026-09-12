# RelayShell

A mobile control center for remote development over SSH, built to [SPEC.md](SPEC.md).

The product model is `Phone → Computer → Project → Session → Action`. A generic SSH
client opens a blank terminal; this app opens what you actually wanted to do —
resume a session, enter a project, launch a CLI, run a saved command, browse files.

## Status

| Check | Result |
| --- | --- |
| `flutter analyze` | run before every release |
| `flutter test` | run before every release |
| Android debug build | run before every release |
| Android release signing | requires a private upload key; cannot fall back to debug signing |

## Requirements

- Flutter 3.47+ (Dart 3.13+)
- Android SDK platform 37.0 (`compileSdk` is pinned in `android/app/build.gradle.kts`)
- Xcode for iOS builds

## Running

```bash
flutter pub get
flutter run
```

## Android release signing

Release artifacts deliberately fail to build until they are configured with a
private upload key. This prevents the Android toolchain from silently signing a
shipping build with its publicly known debug certificate.

```bash
keytool -genkeypair -v -keystore ~/relayshell-upload.jks \
  -alias upload -keyalg RSA -keysize 4096 -validity 10000
cp android/key.properties.example android/key.properties
```

Set the four values in `android/key.properties`, using an absolute path for
`storeFile`, then build the store upload artifact:

```bash
flutter build appbundle --release
```

Never commit `android/key.properties` or the keystore. Back up the upload key
outside this repository; losing it prevents future Android updates. Confirm
that `com.relayshell.relayshell` is registered to the intended Play developer
account before the first upload, because an Android application ID cannot be
changed after publication.

## Conversation Shell

On a POSIX computer or project, choose **Open Shell** to use the mobile command
composer. Enter supports multiple lines; tap Run (or Ctrl/Command+Enter on an
external keyboard) to submit. Commands run in one
live Bash PTY, so `cd`, `export`, functions, aliases and sourced environments carry
over to the next command. No AI service or separate per-command SSH channel is used.

- Draft the next command while output streams; it cannot run until the current
  command completes. History buttons restore earlier commands and your draft.
- Each card shows its exit status and duration, coloured by outcome (blue while
  running, amber when the result is lost or interrupted, red only for a non-zero
  exit — command failure is a result, not an application error). Status changes
  are announced to screen readers. Its menu supports copy, edit, rerun and saving
  through the existing command editor. Output is selectable, copyable and shareable.
- Stop sends Ctrl+C. For passwords, editors, pagers and other interactive tools,
  switch to Terminal: it displays the **same running PTY**, without restarting
  work. Both actions are available directly on the running card as well as in the
  status row.
- A shell opened into a working directory shows that directory in the tab label next
  to the host.
- Reading older output pauses automatic scrolling; Latest output returns to the
  live result. Input controls adapt to the keyboard and landscape layouts.

This first implementation requires Bash and uses a **direct connection**, not a
tmux/Herdr session. Reconnection starts a fresh shell; an interrupted connection
leaves the running result unknown and never replays commands. After typing in
Terminal, conversation submission stays disabled until a fresh shell is opened
because terminal input may bypass command framing. Inspect ongoing work before
using Reconnect. Existing persistent Terminal sessions remain the choice for work
that must survive a lost mobile connection.

The dedicated shell inherits the SSH environment but does not automatically source
Bash startup files. You can source an environment explicitly. Commands that replace
the shell (`exec`), disable its prompt hook, or enable incompatible shell options
may require Terminal. Conversation output is plain text, not a full TUI renderer.
Use foreground commands: background jobs can write output outside their card's
boundaries, so use Terminal to inspect those jobs.

Transcripts and drafts are memory-only and disappear when a tab closes or the app
process exits. At most 50 cards and the last 32K UTF-16 characters of output per
card are retained; truncation is labeled. Input is limited to 16K characters.
Clear removes completed cards. Saving a command and sharing/copying output are
explicit user actions; the shell's automatic history file is disabled.

## Herdr on your phone

For an existing Herdr workflow, set the computer's multiplexer to **Herdr**, then
choose **Herdr panes** on the computer or project. Select the named session and
pane by its title, agent status and working directory. This requires a POSIX
host with Herdr's native terminal-control CLI (tested with 0.8.0).

- A multiline composer sends prompts to recognized agents or commands to shell
  panes. Enter inserts a newline; Send or Ctrl/Command+Enter submits.
- Scroll, Stop (Ctrl+C), and Escape are available above the composer. Switch to
  the raw keyboard for editors, passwords and interactive terminal applications.
- Reconnect and Home's Continue shortcut use the same stable terminal ID, so
  remote work survives a phone disconnect. There is no automatic controller
  takeover, input replay, or fallback to a different pane.
- Unconfirmed delivery retains the draft: inspect the pane before retrying.
  Drafts are memory-only. Detach releases control; forgetting a shortcut does
  not stop the remote pane or the daily Herdr session.

Herdr supplies rendered terminal frames, so this view preserves the agent/TUI
screen rather than claiming command-card boundaries, exit codes or a chat
transcript. Structured Bash cards remain the separate **Open Shell** workflow.

## Architecture

Layered, per SPEC 24. Dependencies point inward: `features` may use `core` and
`shared`; `core` never imports a feature or a widget.

```
lib/
├── app/          router, theme, provider graph, app shell
├── core/
│   ├── ssh/      connection lifecycle, host verification, SFTP, forwarding, tmux
│   ├── shell/    command construction — quoting, variables, danger heuristics
│   ├── security/ fingerprints, key material, biometrics, app lock, redaction
│   ├── storage/  secure storage boundary, config import/export
│   ├── database/ SQLite schema, migrations, repositories
│   └── platform/ Wake-on-LAN, wakelock, clipboard, secure window
├── features/     one folder per product area (SPEC 6)
├── shared/       models, widgets, utilities
└── l10n/         ARB translations (SPEC 38 — no hard-coded UI strings)
```

### Key decisions

**One SSH connection per host, shared by every channel.** Terminals, the file
browser and port forwards multiplex over one transport, so a second terminal is
instant instead of a fresh handshake, and a phone holds one socket per machine.

**Secrets never touch SQLite.** `credentials` stores metadata and an id; the key,
password and passphrase live in the Keychain / Android Keystore behind
`SecretStore`. The split is at the repository boundary so it stays checkable.

**Host keys are matched by endpoint, not by host id.** Editing a host's hostname
or port cannot inherit a trust decision made for a different machine (SPEC 8.4).
A changed fingerprint blocks the connection with no override in the flow.

**Generated commands are always quoted; saved commands never are.** Anything the
app builds goes through `ShellQuoter`; a user's saved command is intentional shell
input and is sent as written (SPEC 29).

**The multiplexer is a product feature, not a hidden trick.** Persistent
sessions exec a single atomic attach-or-create — `tmux new-session -A` or
`herdr --session` — so the channel *is* the multiplexer client and reconnect
lands back in the same work. The backend is chosen per host, because it depends
on what is installed there; `core/shell/multiplexer.dart` holds the seam.

**A persistent session must be scrollable.** A multiplexer puts the emulator in
the alternate screen buffer, which has no scrollback, so a touch drag can only
scroll by reaching the remote program as a mouse-wheel event. Herdr captures the
mouse by default; tmux does not, so the app sets `mouse on` when it attaches.
Without that the drag does nothing at all — not even xterm.dart's arrow-key
fallback. `test/features/terminal_scroll_test.dart` pins both halves.

## Testing

```bash
flutter test
```

The suite favours checking real properties over restating the implementation:

- **Shell quoting** round-trips 22 hostile inputs (`$(whoami)`, `'; rm -rf /`,
  globs, CJK) through the actual `/bin/sh` and asserts each comes back byte-identical
  as a single argument.
- **Key generation** is verified by `ssh-keygen -y`, which must derive the same
  public key and fingerprint from a key this app produced.
- **Security gates** in `security_acceptance_test.dart` encode SPEC 44 as
  executable checks — including a scan of every table for key material and a
  source scan proving host-key verification is never disabled.
- **Widget tests** run against the real service graph (real repositories, router
  and screens) on an in-memory database.

## Release gates

Automated checks cannot prove OS prompts, device keyboards, or real SSH server
interoperability. Follow [the release checklist](docs/RELEASE_CHECKLIST.md) on
physical Android and iOS devices before publishing. The checklist includes the
computers, projects, sessions, reconnection, tmux, biometric, file transfer,
and accessibility paths that need a human/device pass.

## Known limitations

- **Ed25519 only** for key generation. Importing accepts RSA, ECDSA and Ed25519,
  encrypted or not.
- **Generated keys are not passphrase-encrypted** inside the PEM. They go straight
  to platform secure storage, which is what protects them at rest; adding a
  passphrase would mean prompting on every connect for no added protection.
  Import a passphrase-protected key if you want one.
- **SSH agent authentication is unavailable** on mobile and reports so explicitly.
- **`FLAG_SECURE` is Android-only.** iOS has no public equivalent, so there the
  lock overlay is the protection.
- **Physical-device verification is a release gate.** It cannot be substituted
  by a Linux CI run; see the linked checklist for the required matrix.

## Privacy

No account, no server, no relay. Terminal output, commands, keys, passwords and
remote file contents stay on the device and the user's own machines. Config export
never includes credentials.

The publishable policy text is in [PRIVACY.md](PRIVACY.md).
