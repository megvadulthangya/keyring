# xlibre-keyring

A Pacman keyring that provides the GPG keys for the **XLibre xserver repositories** on Arch Linux and Manjaro.

It replaces the old `xlibre` repo signing key with the new keys used for both Arch‑based (`xlibre-archlinux`) and Manjaro‑specific (`xlibre-manjarolinux`) packages.

## Quick start

1. **Install the keyring package**  
   ```bash
   sudo pacman -U xlibre-keyring-*.pkg.tar.zst
   ```

2. **Populate the keyring** (package install does this automatically)  
   ```bash
   sudo pacman-key --populate xlibre
   ```

3. **Add the repository** to `/etc/pacman.conf`  
   The installer will print the correct `[xlibre]` section for your distribution.

## How it works

The package contains two ASCII‑armored public keys (`.gpg` files) that are combined into a single keyring file (`xlibre.gpg`) during build time. Together with the `xlibre-trusted` and `xlibre-revoked` lists, this allows `pacman-key` to verify package signatures.

## Building from source

Requires `base-devel`, `gnupg`, `sudo`, and optionally `git`.

```bash
git clone https://github.com/xlibre/xlibre-keyring.git
cd xlibre-keyring
makepkg -si
```

## Repository structure

| File | Purpose |
|------|---------|
| `PKGBUILD` | Build recipe |
| `Makefile` | Build automation (imports keys, generates keyring) |
| `xlibre-keyring.install` | Post‑install hooks (populate keyring, branch detection) |
| `xlibre-archlinux.gpg` | Arch Linux repository signing key |
| `xlibre-manjarolinux.gpg` | Manjaro repository signing key |
| `xlibre-trusted` | List of trusted key fingerprints |
| `xlibre-revoked` | List of revoked key fingerprints |

## GitHub Actions

Two workflows are provided:

- **Build** (`build.yml`)  
  Runs on every push to the `xlibre` branch. Builds the package in an Arch Linux container and stores the artifact.

- **Release** (`release.yml`)  
  Triggered manually (`workflow_dispatch`). Updates `pkgver` to today’s date, rebuilds the package, and creates a GitHub release with a version tag (e.g. `v20260710`).

## Maintainer information

For detailed instructions on updating keys, modifying the trusted/revoked lists, and performing a new release, please refer to the maintainer guide:

📚 **[MAINTAINER.md](MAINTAINER.md)**
```
