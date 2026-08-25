# RelayShell release checklist

Run this checklist against the exact signed candidate that will be uploaded.
Automated tests are necessary but cannot validate device prompts, mobile
networks, external keyboards, or a real SSH daemon.

## Credentials and packaging

- [ ] Run `flutter analyze` and `flutter test` from a clean checkout.
- [ ] Build an Android App Bundle with `flutter build appbundle --release`.
- [ ] Verify the artifact with `apksigner verify --verbose --print-certs` and
  confirm its certificate is the private upload certificate, never the Android
  debug certificate.
- [ ] Confirm the Android application ID is owned by the intended Play account.
- [ ] On macOS, archive the iOS app with the intended Apple development team;
  confirm the Keychain Sharing entitlement is present in the signed app.
- [ ] Keep the Android upload keystore and iOS signing credentials outside the
  repository and verify their backup/recovery procedure.

## Device and security matrix

- [ ] Android 8 or later: launch, enable/disable app lock, authenticate with
  biometric and device credential, and confirm an unavailable biometric prompt
  leaves the app locked rather than opening it.
- [ ] Recent Android and iOS: confirm saved credentials survive restart, are
  protected by the OS prompt when configured, and are absent from a config
  export.
- [ ] With app lock enabled, verify the app switcher does not show terminal
  output on Android and that the iOS lock overlay appears before content.
- [ ] Connect to an unknown SSH host, compare and accept its fingerprint, then
  reconnect without another prompt. Change the host key and verify that the
  connection is blocked.
- [ ] Use **Test Connection** before saving a computer, accept its host key,
  save the computer, then reconnect without another host-key prompt.

## Product-flow matrix

- [ ] Add, edit, delete, and test two distinct computers. Confirm connecting
  one does not create duplicate sessions when Connect is pressed repeatedly.
- [ ] Create, edit, open, and delete a project on each computer; verify the
  remote working directory is used only when it exists.
- [ ] Open direct and persistent sessions, switch tabs, close an idle tab, and
  verify that a full set of live tabs asks the user to close one instead of
  silently ending remote work.
- [ ] Create a tmux session, detach it, resume it from Sessions, and attach a
  discovered tmux session. Repeated Resume/Attach must focus the same tab.
- [ ] Disconnect a Wi-Fi or Tailscale transport during a terminal. Verify a
  configured automatic reconnect restores the terminal channel; direct shells
  reopen honestly and persistent shells return to the same tmux session.
- [ ] Start each port-forward type, then disconnect the host. Verify the UI
  clears its stale running state and local listening sockets are closed.
- [ ] Upload/download a large file through the system file picker; cancel a
  long one-shot command and verify only its exec channel stops.

## Terminal and accessibility matrix

- [ ] Test `vim`, `htop`, coloured output, CJK text, resize/orientation,
  selection/copy/paste, Ctrl and Alt shortcuts, and a Bluetooth keyboard.
- [ ] Test VoiceOver/TalkBack navigation, large text, light/dark themes, and
  keyboard-only navigation where supported.
- [ ] Verify the new launcher icon, RelayShell display name, version, privacy
  policy link, and store screenshots/descriptions match the candidate.

Record the device model, OS version, SSH server, network type, and outcome for
each failed or exceptional case before approving a release.
