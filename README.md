# Remote Dev Console (RelayShell)

A mobile control center for remote development over SSH, built to [SPEC.md](SPEC.md).

The product model is `Phone → Computer → Project → Session → Action`. A generic SSH
client opens a blank terminal; this app opens what you actually wanted to do —
resume a session, enter a project, launch a CLI, run a saved command, browse files.

## Status

| Check | Result |
| --- | --- |
| `flutter analyze` | 0 issues |
| `flutter test` | 275 passing |
| `flutter build apk --debug` | builds |
| `flutter build apk --release` | builds (64.6 MB) |

## Requirements

- Flutter 3.47+ (Dart 3.13+)
- Android SDK platform 36 (`compileSdk` is pinned to 36 in `android/app/build.gradle.kts`)
- Xcode for iOS builds

## Running

```bash
flutter pub get
flutter run
```

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

**tmux is a product feature, not a hidden trick.** Persistent sessions exec
`tmux new-session -A`, a single atomic attach-or-create, so the channel *is* the
tmux client and reconnect lands back in the same work.

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
- **Not verified on physical devices.** Builds and the full suite pass, but
  SPEC 43's device and terminal-compatibility matrix (vim, htop, CJK rendering,
  Bluetooth keyboards, real SSH servers) still needs a hardware pass.

## Privacy

No account, no server, no relay. Terminal output, commands, keys, passwords and
remote file contents stay on the device and the user's own machines. Config export
never includes credentials.
