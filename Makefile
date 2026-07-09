# Makefile for xlibre-keyring
# This file handles keyring generation (update) and installation.
#
# Update target downloads the Arch and Manjaro public keys using a
# fallback chain: primary URL → keyserver.ubuntu.com → keys.openpgp.org.
# The resulting keyring is exported as xlibre.gpg.
#
# Installation follows the standard pacman keyring layout.

V        = 20260709
PREFIX   = /usr
KEYDIR   = $(DESTDIR)$(PREFIX)/share/pacman/keyrings/

# Key fingerprints for XLibre repositories
ARCH_KEY_ID     = B97F7C613F359424
MANJARO_KEY_ID  = D1445F51BC0A8969

# URLs to the official key files (primary fetch source)
ARCH_URL        = https://xlibre-arch.github.io/xlibre-archlinux.asc
MANJARO_URL     = https://xlibre-manjaro.github.io/xlibre-manjarolinux.asc

# Temporary GPG home for import operations
TEMPHOME = $(shell mktemp -d)

.PHONY: update install uninstall

update:
	@echo "==> Obtaining Arch Linux XLibre key ($(ARCH_KEY_ID))"
	@# Try primary URL first, then ubuntu keyserver, then openpgp.org
	@curl -fsS $(ARCH_URL) -o $(TEMPHOME)/arch.asc 2>/dev/null && \
	  gpg --homedir $(TEMPHOME) --import $(TEMPHOME)/arch.asc 2>/dev/null || \
	 (echo "   Primary URL failed, trying keyserver.ubuntu.com..."; \
	  gpg --homedir $(TEMPHOME) --keyserver hkp://keyserver.ubuntu.com --recv-keys $(ARCH_KEY_ID) 2>/dev/null) || \
	 (echo "   Ubuntu keyserver failed, trying keys.openpgp.org..."; \
	  gpg --homedir $(TEMPHOME) --keyserver hkps://keys.openpgp.org --recv-keys $(ARCH_KEY_ID) 2>/dev/null) || \
	 { echo "ERROR: Could not obtain Arch key!"; exit 1; }

	@echo "==> Obtaining Manjaro XLibre key ($(MANJARO_KEY_ID))"
	@# Same fallback chain for Manjaro key
	@curl -fsS $(MANJARO_URL) -o $(TEMPHOME)/manjaro.asc 2>/dev/null && \
	  gpg --homedir $(TEMPHOME) --import $(TEMPHOME)/manjaro.asc 2>/dev/null || \
	 (echo "   Primary URL failed, trying keyserver.ubuntu.com..."; \
	  gpg --homedir $(TEMPHOME) --keyserver hkp://keyserver.ubuntu.com --recv-keys $(MANJARO_KEY_ID) 2>/dev/null) || \
	 (echo "   Ubuntu keyserver failed, trying keys.openpgp.org..."; \
	  gpg --homedir $(TEMPHOME) --keyserver hkps://keys.openpgp.org --recv-keys $(MANJARO_KEY_ID) 2>/dev/null) || \
	 { echo "ERROR: Could not obtain Manjaro key!"; exit 1; }

	@echo "==> Exporting combined keyring to xlibre.gpg"
	@gpg --homedir $(TEMPHOME) --export --armor $(ARCH_KEY_ID) $(MANJARO_KEY_ID) > xlibre.gpg
	@rm -rf $(TEMPHOME)
	@echo "==> Keyring update complete"

install:
	install -dm755 $(KEYDIR)
	install -m0644 xlibre{.gpg,-trusted,-revoked} $(KEYDIR)

uninstall:
	rm -f $(KEYDIR)xlibre{.gpg,-trusted,-revoked}
	rmdir -p --ignore-fail-on-non-empty $(KEYDIR)