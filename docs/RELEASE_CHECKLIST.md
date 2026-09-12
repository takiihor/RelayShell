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
