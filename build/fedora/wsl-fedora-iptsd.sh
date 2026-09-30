#!/usr/bin/env bash
# iptsd (alex-lentz-Fork, haptischer Klick) im Fedora-Chroot mit Fedoras eigener Toolchain bauen und installieren.
# Baut mit Fedoras Standard-Flags (-mbranch-protection=standard durchgaengig) -> kein SIGILL-Risiko wie beim ELLX-Deb.
set -uo pipefail
export LC_ALL=C
H="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora/wsl-fedora-chroot.sh"
R=/work/sl7/fedora/rootfs
bash "$H" mount >/dev/null || exit 1
echo "=== [1] Quelle (git clone in WSL, damit LF-Zeilenenden)"
mkdir -p "$R/root/sl7"
if [ ! -d "$R/root/sl7/iptsd/.git" ]; then git clone -q --depth 20 https://github.com/alex-lentz/iptsd "$R/root/sl7/iptsd" || exit 1; fi
git -C "$R/root/sl7/iptsd" log -1 --format='    %h %cd %s' --date=short
echo "=== [2] Build-Abhaengigkeiten (dnf im Chroot, braucht Netz)"
bash "$H" run dnf -y -q install meson ninja-build gcc-c++ cmake pkgconf-pkg-config cli11-devel eigen3-devel fmt-devel inih-devel spdlog-devel guidelines-support-library-devel 2>&1 | tail -3
echo "=== [3] meson/ninja"
bash "$H" run bash -c 'cd /root/sl7/iptsd && rm -rf build && meson setup build --buildtype=release -Dsample_config=true -Dservice_manager=systemd -Ddebug_tools=disabled 2>&1 | tail -5 && ninja -C build 2>&1 | tail -3' || { echo "Build fehlgeschlagen"; exit 1; }
echo "=== [4] Installation ins Rootfs (DESTDIR=/)"
bash "$H" run bash -c 'cd /root/sl7/iptsd && DESTDIR=/ ninja -C build install 2>&1 | tail -3'
echo "=== [5] Ergebnis"
ls -la "$R/usr/bin/iptsd" "$R/usr/bin/iptsd-calibrate" "$R/usr/bin/iptsd-check-device" 2>&1
ls -la "$R"/usr/lib/systemd/system/iptsd@.service "$R"/usr/lib/udev/rules.d/*iptsd* "$R"/usr/lib/systemd/system-sleep/iptsd 2>&1
echo "--- BTI/PAC-Eigenschaften (branch-protection):"; bash "$H" run readelf -n /usr/bin/iptsd 2>/dev/null | grep -A1 -i 'AArch64 feature' | head -3
echo "--- Abhaengigkeiten:"; bash "$H" run ldd /usr/bin/iptsd 2>/dev/null | head -12
echo "--- Kalibrierung (15\"-Startwert aus ELLX):"
mkdir -p "$R/etc/iptsd.d"; cp -f "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out/ellx-iptsd/91-calibration-045E-0C77.conf" "$R/etc/iptsd.d/" && cat "$R/etc/iptsd.d/91-calibration-045E-0C77.conf"
cat > "$R/etc/iptsd.d/90-sl7-touchpad.conf" <<'EOF'
# Surface Laptop 7 (haptisches Trackpad, 045E:0C77): Klick-Entprellung des alex-lentz-Forks, Handballen-Unterdrueckung
[Touchpad]
ButtonDebounceMs = 25
DisableOnPalm = true
EOF
echo "=== [6] Build-Reste entfernen (Quelle bleibt fuer Nachbauten unter /root/sl7/iptsd)"
rm -rf "$R/root/sl7/iptsd/build"
bash "$H" run dnf -y -q clean all >/dev/null 2>&1
echo "fertig"
