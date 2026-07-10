# Maintainer Guide – xlibre-keyring

This document explains how to manage the keyring package, update keys, and release new versions.

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

## Common pitfalls

- **Missing trailing newline in `xlibre-trusted`** → `pacman-key` will ignore the last key.
- **Incorrect trust level** – must be `:4:`.
- **Forgetting to update `sha256sums`** – the build will pass (if `SKIP` is used), but the checksums won’t match the actual files.
- **Using the old `.asc` extension** – `makepkg` treats `.asc` files as detached signatures. Use `.gpg` instead.
- **Missing `gnupg` as `makedepends`** – the keyring won’t be generated.
