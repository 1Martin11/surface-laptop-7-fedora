#!/usr/bin/env bash
# Phase 1 im Fedora-Rootfs (Chroot): vollstaendiges Update (ohne Kernel), iptsd-RPM bauen + installieren, Build-Werkzeuge wieder entfernen.
set -uo pipefail; export LC_ALL=C
B="/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/fedora"; H="$B/wsl-fedora-chroot.sh"; R=/work/sl7/fedora/rootfs
L=/work/sl7/fedora/phase1.log; : > "$L"
sed -i 's/\r$//' "$H" "$B/iptsd-sl7.spec"
bash "$H" mount >/dev/null || exit 1
run() { bash "$H" run "$@"; }
echo "=== [1] SELinux-Labels vorhanden?"; getfattr --absolute-names -n security.selinux "$R/etc/passwd" "$R/usr/bin/bash" 2>&1 | grep 'security' 
echo "=== [2] dnf upgrade (ohne kernel*), Log: $L"; START=$(date +%s)
run dnf -y --refresh upgrade --exclude='kernel*' >> "$L" 2>&1; echo "    exit=$? Dauer $(( ($(date +%s)-START)/60 )) min"; grep -E '^(Upgrading|Installing|Removing|Total|Complete)' "$L" | tail -3; grep -ciE 'error|fail' "$L" | sed 's/^/    error\/fail-Zeilen im Log: /'
echo "=== [3] Build-Werkzeuge"; run dnf -y install rpm-build rpmdevtools meson ninja-build gcc-c++ cmake pkgconf-pkg-config cli11-devel eigen3-devel fmt-devel inih-devel spdlog-devel guidelines-support-library-devel systemd-rpm-macros >> "$L" 2>&1; echo "    exit=$?"
echo "=== [4] iptsd-RPM"
mkdir -p "$R/root/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD}
git -C "$R/root/sl7/iptsd" archive --prefix=iptsd-3663e96/ -o "$R/root/rpmbuild/SOURCES/iptsd-3663e96.tar.gz" 3663e96 || exit 1
cp -f "$B/iptsd-sl7.spec" "$R/root/rpmbuild/SPECS/iptsd.spec"
run rpmbuild -bb /root/rpmbuild/SPECS/iptsd.spec > /work/sl7/fedora/iptsd-rpm.log 2>&1; rc=$?; echo "    rpmbuild exit=$rc"; [ $rc = 0 ] || { grep -nE 'error|Error|FAILED|Installed \(but unpackaged\)' -A3 /work/sl7/fedora/iptsd-rpm.log | head -30; exit 1; }
RPM=$(ls "$R"/root/rpmbuild/RPMS/aarch64/iptsd-3-*.rpm | grep -v debug | head -1); echo "    $RPM"
rpm -qpl "$RPM" | sed 's/^/      /'
echo "--- Requires:"; rpm -qpR "$RPM" | grep -v rpmlib | tr '\n' ' '; echo
mkdir -p "$B/out/iptsd"; cp -f "$RPM" "$B/out/iptsd/"; (cd "$B/out/iptsd" && sha256sum *.rpm > SHA256SUMS)
echo "=== [5] iptsd installieren, Build-Werkzeuge entfernen"
run dnf -y install "${RPM#$R}" >> "$L" 2>&1; echo "    install exit=$?"
run dnf -y remove rpm-build rpmdevtools meson ninja-build gcc-c++ gcc cmake cli11-devel eigen3-devel fmt-devel inih-devel spdlog-devel guidelines-support-library-devel >> "$L" 2>&1; echo "    remove exit=$?"
run rpm -q iptsd fmt spdlog inih 2>&1 | sed 's/^/    /'
echo "--- Binaer-Eigenschaften:"; run readelf -n /usr/bin/iptsd 2>/dev/null | grep -A1 -i 'feature' | head -3; run ldd /usr/bin/iptsd | head -8
run dnf -y clean all >/dev/null 2>&1; rm -rf "$R/root/rpmbuild/BUILD" "$R/var/cache/dnf" "$R/var/cache/libdnf5"
echo "=== [6] Kalibrierung/Config"; mkdir -p "$R/etc/iptsd.d"
cp -f "/mnt/c/Users/Martin/Desktop/Projekt Linux ARM/build/out/ellx-iptsd/91-calibration-045E-0C77.conf" "$R/etc/iptsd.d/"
cat > "$R/etc/iptsd.d/90-sl7-touchpad.conf" <<'EOC'
# Surface Laptop 7 (haptisches Trackpad, 045E:0C77): Entprellung des Force-Klicks (alex-lentz-Fork), Handballen-Unterdrueckung
[Touchpad]
ButtonDebounceMs = 25
DisableOnPalm = true
EOC
ls -la "$R/etc/iptsd.d/"; du -sh "$R" 2>/dev/null | tail -1
echo "=== Phase 1 fertig"
