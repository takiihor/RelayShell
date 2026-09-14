# RelayShell Release Checklist

Automated tests cover command construction, persistence, security boundaries,
routing and widget behaviour. The following checks require a physical device,
real OS prompts, or a real SSH server and must be completed before release.

## Build and signing

- [ ] `flutter analyze` passes with no issues.
- [ ] `flutter test` passes completely.
- [ ] Android debug build installs on a physical device.
- [ ] Android release/app bundle is signed with the intended private upload key.
- [ ] iOS release build/archive succeeds with the intended signing identity.

## Connection and security

- [ ] Connect to a new SSH host and verify the first-use fingerprint dialog.
- [ ] Confirm a changed host key blocks the connection and clearly shows the mismatch.
- [ ] Confirm private keys/passwords remain in platform secure storage and never appear in exported configuration.
- [ ] Test password, keyboard-interactive, imported-key and generated-key authentication paths that are intended for the release.
- [ ] Background and foreground the app during a live connection and confirm reconnect behaviour is bounded and understandable.

## Terminal and sessions

- [ ] Open a direct terminal and verify typing, selection, copy/paste and UTF-8/CJK text.
- [ ] Verify ESC, CTRL, ALT, SHIFT, TAB, arrows and configured accessory keys on the device keyboard.
- [ ] Verify Shift+Tab and Shift+arrow sequences in an interactive terminal program.
- [ ] Start and resume a persistent tmux session.
- [ ] Start and resume a Herdr-backed session on a host configured for Herdr.
- [ ] Verify touch scrolling inside persistent full-screen terminal programs.
- [ ] Verify detach leaves persistent remote work running.

## Conversation Mode

- [ ] Open Conversation Mode from a Computer and verify it starts from a clean direct shell.
- [ ] Open Conversation Mode from a Project and verify the project working directory is applied.
- [ ] Run `cd` and `export`, then verify later commands see the changed directory/environment.
- [ ] Verify command output streams into the active card and reports the final exit code.
- [ ] Verify `Ctrl+C` stops the foreground command without closing the SSH connection.
- [ ] Verify the compact shortcut row includes ESC, CTRL, SHIFT, ALT, TAB and `/`.
- [ ] With a foreground interactive command, verify accessory keys are sent as raw PTY input rather than inserted into the composer.
- [ ] Verify CTRL then soft-keyboard `b` sends Ctrl+B while an interactive command is running.
- [ ] Launch Herdr from Conversation Mode, send at least two text messages through the Conversation composer, and verify Herdr receives them rather than RelayShell framing/footer text.
- [ ] Verify Herdr/Codex/Claude/Pi or another interactive CLI can receive TAB, Shift+Tab, arrows, ESC and Ctrl+C from Conversation Mode.
- [ ] Launch a full-screen TUI and verify Conversation Mode detects alternate-screen use and offers `Open in terminal`.
- [ ] Open Terminal from a running Conversation command and verify it displays the same live PTY/process rather than launching it again.
- [ ] Verify a very large output stream remains bounded and does not cause visible memory growth or UI lockup.

## Conversation Shell (release gate)

- [ ] On Android and iOS, open Shell from a computer and project. Run `cd`,
  `export`, a function, an alias and environment activation across separate cards.
- [ ] Enter multiline text with CJK/emoji, paste shell punctuation, and compose
  text using an IME. Run must not submit uncommitted IME composition. Verify
  history preserves the draft and running commands cannot accept another submission.
- [ ] Run streaming logs and Stop them. Confirm interruption returns a prompt
  without closing the shared SSH connection or disrupting another terminal.
- [ ] Open an editor or password prompt and switch to Terminal. Confirm the same
  process continues and the draft survives switching views. After terminal input,
  confirm the conversation requests a fresh shell instead of guessing boundaries.
- [ ] Verify portrait, landscape, keyboard insets, large text, TalkBack/VoiceOver,
  light/dark mode, copy/select/share (including iPad share anchoring), and saved
  command editing. Scroll back while output streams, then use Latest output.
- [ ] Exceed the output/card limits and verify visible truncation and responsive
  scrolling. Clear completed cards while a command runs.
- [ ] Lose the network during a command, reconnect, and verify an unknown result,
  a fresh direct shell and no replay. Do not imply tmux/Herdr resume support here.

### Herdr native panes

- [ ] On a physical phone, choose a named Herdr session/pane, send a multiline
  Unicode prompt to a real coding agent, and verify Enter remains a newline.
- [ ] Verify raw keyboard, Ctrl+C, Escape, remote scroll and keyboard resize.
- [ ] Drop Wi-Fi during remote work and reconnect to the same stable terminal;
  verify no prompt is replayed. Repeat after app restart via Continue.
- [ ] Verify a competing controller is refused without takeover; detach keeps
  the pane running. Forget must not offer to kill the entire Herdr session.
- Automated coverage: NDJSON framing/ordering/bounds; composer IME, uncertain
  delivery, draft preservation and small-screen layouts; schema migration and
  distinct pane shortcuts. The opt-in `herdr_live_test.dart` executes production
  bridge commands against a disposable local Herdr session (not a phone or an
  SSH transport test). Never point it at a daily-use session.
- [ ] Test a host without Bash, a missing project directory, and commands that
  replace the shell or change `PROMPT_COMMAND`; verify Terminal remains reachable
  and no successful command result is fabricated.

Record the device model, OS version, SSH server, network type, and outcome for
each failed or exceptional case before approving a release.
## Projects, files and commands

- [ ] Open a project and confirm its configured remote path is used safely, including paths with spaces and CJK characters.
- [ ] Run saved one-shot and interactive commands and verify cancellation/confirmation flows.
- [ ] Browse, upload, download, rename and delete files over SFTP.
- [ ] Verify port forwarding profiles used for the release on a real remote host.

## Mobile UX and accessibility

- [ ] Test portrait and landscape on at least one Android phone and one iPhone.
- [ ] Confirm the Conversation shortcut row remains one horizontally scrollable row and does not create a duplicate bottom safe-area gap above the composer.
- [ ] Confirm terminal accessory keys maintain at least 48dp touch targets.
- [ ] Test with a hardware keyboard where available.
- [ ] Check system font scaling, screen reader labels and light/dark appearance.
- [ ] Confirm Android system navigation does not overlap bottom controls.

## Final verification

- [ ] Repeat the smoke path from a clean install with no stored hosts or credentials.
- [ ] Confirm the published privacy text matches actual application behaviour.
- [ ] Confirm version/build numbers and store metadata are correct.
