# Maintainer Guide – xlibre-keyring

This document explains how to manage the keyring package, update keys, release new versions, and integrate the keyring into a Manjaro ISO.

## Package overview

The `xlibre-keyring` package provides the GPG keys that users need to verify packages from the XLibre repositories.  
It contains:

- **Two public key files** (`.gpg`), one for Arch Linux, one for Manjaro.
- **`xlibre-trusted`** – defines which keys are trusted (and their trust level).
- **`xlibre-revoked`** – lists revoked keys.
- **`Makefile`** – builds the combined keyring (`xlibre.gpg`) from the individual key files.
- **`PKGBUILD`** – standard Arch build script.
- **`xlibre-keyring.install`** – post‑installation tasks (populating the keyring, branch‑specific repository advice).

When the package is installed or upgraded, `pacman-key --populate xlibre` is called. This command:

1. Imports all keys from `xlibre.gpg`.
2. Locally signs the keys listed in `xlibre-trusted`.
3. Disables any keys from `xlibre-revoked`.

## Keyring File Format

The keyring relies on two plain text files that define which keys are trusted and which are revoked:

### `xlibre-trusted`

- Each line must contain exactly one key fingerprint followed by `:4:` (the trust level that marks the key as ultimately trusted).
- Example: `A9A569C8F797B6878E44C4F8FBF4AB57E9BB9D3C:4:`
- **The file must end with a single newline character.** If the final line is missing the newline, `pacman-key --populate` will silently ignore that key, resulting in “unknown trust” errors when verifying signatures.
- Do **not** add extra spaces, comments, or blank lines inside the file.

### `xlibre-revoked`

- Contains one key fingerprint per line for each key that has been revoked.
- Example: `A9A569C8F797B6878E44C4F8FBF4AB57E9BB9D3C`
- If no keys are revoked, the file must exist but be completely empty.

### Important warnings

- Always verify that `pacman-key --populate xlibre` outputs `Locally signing trusted keys` after you make changes. If that line is missing, a format error (usually a missing trailing newline) is likely.
- Never edit these files by hand without checking the exact byte content afterwards, e.g., with `xxd xlibre-trusted`. A BOM or extra spaces will break the parsing.
- After modifying these files, rebuild the keyring package and re-run `pacman-key --populate xlibre` on every affected system.

## Updating the signing keys

If the repository signing key changes:

1. **Obtain the new public key** and export it as ASCII‑armored:
   ```bash
   gpg --export --armor NEWKEYID > xlibre-archlinux.gpg   # or manjarolinux
   ```
2. **Update the `xlibre-trusted` file** with the new fingerprint and trust level:
   ```
   NEWKEYID:4:
   ```
   Remove the old key if it is no longer in use.
3. **If the old key must be revoked**, add its fingerprint to `xlibre-revoked`.
4. **Update the `sha256sums` in `PKGBUILD`** to match the new `.gpg` file(s).
5. **Rebuild** the package (`makepkg`) and test on a clean system.

## Testing the keyring

After a build, you can manually test the keyring without installing:

```bash
# Combine keys
make update
# Inspect the generated keyring
gpg --show-keys xlibre.gpg

# Simulate pacman-key populate (on a test system)
sudo pacman-key --init
sudo pacman-key --populate xlibre
# Verify trust
pacman-key --list-keys
```

## CI / Release workflows

### Build workflow (`.github/workflows/build.yml`)

- Triggered on every push to the `xlibre` branch.
- Uses the official `archlinux:latest` container.
- Creates a `builder` user, installs dependencies, and runs `makepkg`.
- The built package is uploaded as a workflow artifact (valid for a limited time).

### Release workflow (`.github/workflows/release.yml`)

- Manually triggered via the GitHub Actions UI (`workflow_dispatch`).
- **No input required** – it automatically uses the current date as the version.
- Steps:
  1. Sets `pkgver` to `YYYYMMDD` (today) and resets `pkgrel` to `1`.
  2. Builds the package.
  3. Creates a GitHub release with a tag `vYYYYMMDD` and attaches the `.pkg.tar.*` artifact.
- The release notes are auto‑generated.

To create a new release:
- Go to the **Actions** tab → **Release** workflow → **Run workflow**.
- Wait for the workflow to finish – the release will appear under the repository’s Releases page.

## Integrating into a Manjaro ISO

To include the XLibre keyring in a custom Manjaro ISO (e.g., a respin), the keyring must be installed and populated on first boot. A systemd service automates this.

### Required files

Place the following files in the respective directories of your ISO profile (e.g., `iso-profiles/manjaro/xfce/desktop-overlay/`):

1. **`usr/local/bin/manjaro-post-install`** (executable script)
   ```bash
   #!/bin/sh
   # First-boot script to initialize the pacman keyring and populate
   # the XLibre repository signing keys.
   # This service runs once and disables itself upon success.

   log_msg() {
       echo "manjaro-post-install: $*"
   }

   # Ensure the pacman master key exists; if not, generate it.
   init_output=$(pacman-key --init 2>&1)
   init_ret=$?
   if [ $init_ret -ne 0 ]; then
       if echo "$init_output" | grep -q "A master key already exists"; then
           log_msg "Pacman master key already present."
       else
           log_msg "ERROR: pacman-key --init failed: $init_output"
           exit 1
       fi
   else
       log_msg "Pacman keyring initialized successfully."
   fi

   # Function to populate a given keyring, with fallback to reinstall from cache if keyring files are missing.
   populate_keyring() {
       local kr="$1"
       local pkg="${kr}-keyring"

       if [ ! -f "/usr/share/pacman/keyrings/${kr}.gpg" ] || \
          [ ! -f "/usr/share/pacman/keyrings/${kr}-trusted" ]; then
           log_msg "WARNING: ${kr} keyring files missing. Trying to reinstall ${pkg} from cache..."
           if command -v pacman >/dev/null && ls /var/cache/pacman/pkg/${pkg}-*.pkg.tar* &>/dev/null; then
               pacman -U --noconfirm /var/cache/pacman/pkg/${pkg}-*.pkg.tar*
               if [ $? -ne 0 ]; then
                   log_msg "ERROR: Failed to reinstall ${pkg} from cache."
                   return 1
               fi
           else
               log_msg "ERROR: Cannot find ${pkg} in cache. Keyring may be broken."
               return 1
           fi
       fi

       log_msg "Populating ${kr} keyring..."
       pacman-key --populate "$kr"
       local ret=$?
       if [ $ret -ne 0 ]; then
           log_msg "WARNING: pacman-key --populate ${kr} failed (exit code $ret). Retrying once..."
           pacman-key --populate "$kr"
           ret=$?
           if [ $ret -ne 0 ]; then
               log_msg "ERROR: pacman-key --populate ${kr} failed after retry."
               return 1
           fi
       fi
       return 0
   }

   # Process only the xlibre keyring
   FAILED=0
   populate_keyring "xlibre" || FAILED=1

   # Disable service only if the keyring was populated successfully
   if [ $FAILED -eq 0 ]; then
       log_msg "XLibre keyring populated successfully. Disabling manjaro-post-install.service."
       systemctl disable manjaro-post-install.service
   else
       log_msg "WARNING: XLibre keyring could not be populated. Service will remain enabled for next boot."
       exit 1
   fi
   ```

2. **`etc/systemd/system/manjaro-post-install.service`**
   ```ini
   [Unit]
   Description=Manjaro Post Install.

   [Service]
   Type=simple
   ExecStart=/usr/local/bin/manjaro-post-install

   [Install]
   WantedBy=default.target
   ```

### Enable the service in `profile.conf`

Edit the ISO profile’s `profile.conf` (e.g., `iso-profiles/manjaro/xfce/profile.conf`) and add `'manjaro-post-install'` to the `enable_systemd` array:

```bash
enable_systemd=('avahi-daemon' 'bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'cups' 'ufw' 'apparmor' 'snapd.apparmor' 'snapd' 'systemd-timesyncd' 'manjaro-post-install')
```

### Build the ISO

Build your ISO using the standard Manjaro ISO tools. After booting the resulting ISO:

- The service runs once.
- The pacman master key is generated if missing (handled idempotently).
- `pacman-key --populate xlibre` trusts the XLibre repository signing key.
- The service disables itself only if the keyring was populated successfully; otherwise it remains enabled and retries on the next boot.

This ensures that packages from the XLibre repository are immediately trusted after installation.
