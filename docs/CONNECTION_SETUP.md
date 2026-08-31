# RelayShell connection setup

This guide configures RelayShell on an Android phone for two common connection
paths:

- **europa** over Tailscale (`100.94.210.28:22`)
- **europa (USB)** over USB debugging (`127.0.0.1:2222`)
- **taki** over Tailscale (`100.114.58.27:22`)

It applies to any Linux SSH host using the same steps. Do not put private keys
or passwords in this document, chat messages, or source control.

## Before you begin

You need:

- RelayShell installed on the phone.
- Android Platform Tools (`adb`) installed on the USB-connected computer.
- A data-capable USB cable, USB debugging enabled on the phone, and the
  phone's RSA debugging prompt accepted by the computer.
- SSH running on each computer.
- Access to each target account's `~/.ssh/authorized_keys` file.
- The Tailscale app connected on the phone before using a Tailscale address.

> [!IMPORTANT]
> Android normally permits one active VPN at a time. Turn off Surfshark or any
> other VPN before connecting Tailscale, otherwise Tailscale IP addresses such
> as `100.114.58.27` will not be reachable.

## 1. Create a phone key

1. In RelayShell, open **Computers** and choose **Add Computer**.
2. Under **Authentication**, tap **Add a key**.
3. Choose **Generate Key**.
4. Give the key a recognizable name, such as `Phone key`, and save it.
5. Copy the generated **public key** displayed by RelayShell.

The public key starts with `ssh-ed25519`. RelayShell keeps the matching private
key in the phone's secure storage; do not export or share it.

## 2. Authorize the phone key on a computer

Sign in to the target computer as the same user that RelayShell will use, then
create the SSH directory with safe permissions if it does not already exist:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Add the copied RelayShell public key as a new line in `~/.ssh/authorized_keys`.
Do not replace existing lines unless you intentionally want to remove those
other login keys.

Optionally inspect the SSH server's general public-key settings:

```bash
sudo sshd -T | grep -E 'pubkeyauthentication|authorizedkeysfile'
```

Expected output includes `pubkeyauthentication yes` and an
`authorizedkeysfile` path containing `.ssh/authorized_keys`. This is not a
complete account-level check: `Match` rules, ACLs, and file ownership can still
affect a particular login. The RelayShell connection test is the final check.

Repeat this section for every computer that should accept the phone key.

## 3. Add europa (USB) over USB

Keep the phone connected to europa by USB, then run this command on europa:

```bash
adb reverse tcp:2222 tcp:22
adb reverse --list
```

The list must contain a `tcp:2222 tcp:22` mapping.

In RelayShell, add a computer with these values:

| Field | Value |
| --- | --- |
| Name | `europa (USB)` |
| Hostname or IP | `127.0.0.1` |
| Port | `2222` |
| Username | `europa` |
| Credential | the generated phone key |
| Remote shell | Linux / macOS / BSD |

Tap **Test Connection**. At the first connection, RelayShell shows a host-key
verification dialog. Note the **key type** shown there. On europa, check the
matching public host-key file; for example, if RelayShell shows `ssh-ed25519`:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
```

For `ecdsa-sha2-*` or `ssh-rsa`, use the corresponding
`ssh_host_ecdsa_key.pub` or `ssh_host_rsa_key.pub` file instead. If that file
is absent or inaccessible, ask the computer administrator to provide the
fingerprint for the key type RelayShell displays.

Tap **Trust** only when the displayed fingerprint exactly matches.
After a successful test, tap **Save**.

> [!NOTE]
> `adb reverse` is temporary. Re-run it after unplugging the phone, restarting
> ADB, or rebooting either device.

## 4. Add computers over Tailscale

1. On the phone, turn off any currently active non-Tailscale VPN.
2. Open Tailscale and connect it to the tailnet.
3. Confirm that the target is online in the same tailnet, that its SSH service
   listens on port 22, and that the tailnet ACL permits the phone to reach it.
4. In Tailscale, confirm the target is reachable before opening RelayShell.

Create a separate computer entry for each transport. Do not use port `2222`
with a Tailscale address: it is reserved for the temporary USB reverse rule.

For **europa** over Tailscale, use:

| Field | Value |
| --- | --- |
| Name | `europa` |
| Hostname or IP | `100.94.210.28` |
| Port | `22` |
| Username | `europa` |
| Credential | the generated phone key |
| Remote shell | Linux / macOS / BSD |

For **taki** over Tailscale, use:

| Field | Value |
| --- | --- |
| Name | `taki` |
| Hostname or IP | `100.114.58.27` |
| Port | `22` |
| Username | `taki` |
| Credential | the generated phone key |
| Remote shell | Linux / macOS / BSD |

Tap **Test Connection**. Note the key type in RelayShell's verification dialog,
then compare the matching fingerprint with the result on taki. For an
`ssh-ed25519` dialog:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
```

Use the ECDSA or RSA host-key file instead if RelayShell shows that key type.
Trust only an exact match, then save the computer. A successful entry shows a
recent **Last connected** time on the Computers page.

> [!NOTE]
> After changing a saved address or port, reopen RelayShell if a detail screen
> still shows the former endpoint. Do not clear the app's data: that would
> remove its saved hosts and private key material.

## Troubleshooting

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| `adb reverse` reports no device | ADB is not installed, the cable is charge-only, or USB debugging is not authorized | Install Android Platform Tools, use a data cable, unlock the phone, and accept the RSA debugging prompt. |
| `127.0.0.1:2222` cannot connect | USB reverse rule is absent | Reconnect USB and run `adb reverse tcp:2222 tcp:22` on europa. |
| Tailscale host times out | Tailscale is disconnected, another VPN is active, the target is offline, or an ACL blocks it | Enable Tailscale, disable the competing VPN, then check the target and tailnet ACL in Tailscale. |
| `Permission denied (publickey)` | The App's current public key is not authorized for that user | Add the current RelayShell public key to that user's `authorized_keys`. |
| Verification dialog shows a different fingerprint | The endpoint may be a different machine or host keys changed | Do not trust it; inspect the SSH server before proceeding. |
| Hosts or keys disappear after reinstalling the App | The App's local data was cleared | Generate a new phone key, authorize its public key again, then recreate hosts. |

## Keeping the setup recoverable

- Prefer installing an update over the existing app instead of uninstalling it.
  Uninstalling normally deletes local host data and secure key material.
- RelayShell configuration export does not include private credentials. Keep a
  secure record of the computers to recreate, but always generate or import
  credentials separately.
- Remove old public keys from `authorized_keys` only after confirming that a
  replacement key works from the phone.
