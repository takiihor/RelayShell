# Remote development with RelayShell

Use Conversation for shell commands, build output, and short prompts. A command
stays active while its foreground program runs: **Send input** talks to that
program; it does not start another shell command. Stop sends Ctrl+C and waits
for the shell to confirm completion. Do not put passwords or tokens into a
conversation: transcripts and composer drafts are held in app memory.

Typing `herdr` in Conversation opens the native pane picker. Select a Herdr
session and pane to work with it in Conversation. The output is a live,
selectable snapshot of that pane, not a parsed history of agent messages. Use
**Send to pane** for text and the accessory row for Escape, Tab, arrows, and
Enter. Stop sends Ctrl+C. Conversation never switches to the full terminal
automatically; **Open Terminal** is an explicit option.

For other interactive commands, input goes to the foreground process.
Multi-line input uses bracketed paste when supported, followed by Enter.
Otherwise each newline is a terminal Enter.

For day-to-day work:

1. Set up SSH using [Connection setup](CONNECTION_SETUP.md), verifying the host
   fingerprint. USB forwarding is temporary; use a reachable network address
   for work away from this computer.
2. Open the project directory before starting the development tool. Commands in
   the same shell retain directory and environment changes.
3. Prefer the Herdr pane picker to attach to an existing workspace and terminal.
   Persistent Herdr/tmux sessions are useful when the phone disconnects; direct
   SSH shells do not promise process survival.
4. Read older output without being pulled back to the newest message. The
   conversation retains at most 50 commands and bounds each command's output;
   save important build/test logs on the remote PC.
5. After reconnecting, inspect the remote state before resending input. A lost
   connection does not prove that the last command or prompt failed to arrive.

## Verification for this change

Automated coverage includes short live prompts, split ANSI escape sequences,
carriage-return redraws, backspace/cursor edits, alternate-screen detection,
input while a command is active, bracketed paste, and a real Bash PTY receiving
input and returning to the shell. Widget checks cover keyboard insets,
landscape, dark mode, and enlarged text.

The opt-in `herdr_live_test.dart` requires an isolated, disposable Herdr session.
A skipped test is not evidence of live Herdr compatibility. Verify on the target
PC: attach a pane, send a prompt, navigate with Tab/Escape, interrupt a task,
switch between Conversation and Terminal, then disconnect/reconnect and confirm
the same remote process survives. See [Release checklist](RELEASE_CHECKLIST.md)
for the broader hardware acceptance checks.

### Earlier verification on 2026-09-14

- `flutter analyze`: no issues; debug Android APK built and installed with an
  in-place update, preserving saved app data.
- Full test run with `RELAY_HERDR_TEST_SESSION` set to an isolated session:
  **384 passed, none skipped**. The disposable server was stopped afterward.
- Physical PGEM10 phone over USB (`127.0.0.1:2222`, ADB reverse to PC port 22):
  checked the SSH host fingerprint, sent input to a running `cat`, stopped it,
  observed exit 130, then ran another command successfully.
- Launched the isolated Herdr workspace from the phone, sent
  `echo RS_HERDR_PHONE_OK`, and verified the result in both the phone's terminal
  display and the native Herdr pane. The composer remained available.

The Bash framing fix uses a temporary SIGINT handler so Ctrl+C reports an
interrupted command even when Bash skips the normal completion footer. Tests
also verify that the pre-existing SIGINT handler is restored afterward. Other
POSIX shells retain the normal footer path; equivalent interruption behavior
has not been verified for every shell.

### Conversation-mode correction

The earlier full-screen substitution was not an adequate phone workflow. Typing
bare `herdr` now opens the native pane picker in both conversation entry paths.
Choosing a pane routes to Conversation, not Terminal. Its composer submits to
the selected stable terminal ID through the native Herdr service. Live output
is selectable text; padding from terminal-width frames is removed without
removing indentation. Escape, Tab, arrows, Enter, Stop, and remote scrolling are
available as touch controls. Full Terminal is opened only by explicit action.

Validation: 388 tests passed in the full suite with the isolated native Herdr
integration enabled. The eight focused flow/composer tests also passed after
the final padding correction. Android analysis/build passed. On the physical
USB-connected phone, typing `herdr`, choosing an isolated session/pane, sending
`echo RS_NATIVE_CONVERSATION_OK`, and using Up then Enter all worked while the
native conversation interface stayed visible. The test server was stopped
without stopping the user's normal Herdr session.
