#!/usr/bin/env bash
# Aktiviert arm64-Multiarch in WSL-Ubuntu (Pakete von ports.ubuntu.com), damit Cross-Builds arm64-Bibliotheken
# (z.B. libssl-dev:arm64 fuer das linux-headers-Paket) finden. Danach wird die Kernel-Paketierung erneut gestartet.
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
echo "=== Multiarch arm64"
dpkg --add-architecture arm64
# Haupt-Quellen auf amd64 beschraenken (sonst sucht apt arm64-Indizes auf archive.ubuntu.com, wo es sie nicht gibt)
for f in /etc/apt/sources.list.d/*.sources; do
  if grep -q "archive.ubuntu.com\|security.ubuntu.com" "$f" && ! grep -q "^Architectures:" "$f"; then
    sed -i 's/^Types: deb$/Types: deb\nArchitectures: amd64/' "$f"
    echo "    $f -> Architectures: amd64"
  fi
done
cat > /etc/apt/sources.list.d/arm64-ports.sources <<EOF
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: resolute resolute-updates resolute-security
Components: main restricted universe multiverse
Architectures: arm64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
apt-get update 2>&1 | grep -E "^(E|W):" | head -5
echo "=== libssl-dev:arm64 + libelf-dev:arm64"
apt-get install -y -qq libssl-dev:arm64 libelf-dev:arm64 2>&1 | grep -vE '^(Selecting|Preparing|Unpacking|Setting up|Processing)' | tail -3
ls /usr/include/aarch64-linux-gnu/openssl/opensslconf.h && echo "    OK opensslconf.h (arm64)"
echo "=== Kernel-Paketierung erneut"
exec bash "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/wsl-build-kernel.sh"
