# Maintainer: XLibre Team <your@email>
# Contributor: Gyöngyösi Gábor <gabor at gshoots dot hu>
# Contributor: Philip Müller <philm[at]manjaro[dot]org>
# Contributor: Bernhard Landauer <bernhard[at]manjaro[dot]org>
# This PKGBUILD is derived from manjaro-keyring to provide GPG keys for the
# XLibre xserver repositories (both Arch and Manjaro variants).
#
# The keyring is generated at build time by the Makefile update target,
# which downloads keys from primary URLs with fallback to keyservers.
# Trusted and revoked key lists are maintained statically.

pkgname=xlibre-keyring
pkgver=20260709
pkgrel=1
pkgdesc="XLibre PGP keyring"
arch=('any')
url="https://github.com/xlibre/xlibre-keyring"
license=('GPL-3.0-or-later')
depends=('pacman')
install="${pkgname}.install"

# Source files: Makefile, trusted list, revoked list.
# The actual keyring (xlibre.gpg) is created during prepare().
source=('Makefile'
        'xlibre-trusted'
        'xlibre-revoked')
sha256sums=('SKIP'
            'SKIP'
            'SKIP')

prepare() {
  # Generate the xlibre.gpg keyring from the Makefile update target.
  # This downloads the public keys using the defined fallback methods.
  cd "$srcdir"
  make update
}

package() {
  # Install the keyring files into /usr/share/pacman/keyrings/
  make DESTDIR="${pkgdir}" install
}