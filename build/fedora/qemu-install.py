#!/usr/bin/env python3
"""Unbeaufsichtigte Anaconda-Installation des SL7-Fedora-ISO in qemu-system-aarch64 (-nographic, seriell).

Modus install: GRUB des ISO seriell steuern -> Kernel (sl7b/sl7a/stock) mit Live-Cmdline + systemd.debug_shell=ttyAMA0 booten
               -> in der Root-Shell warten bis multi-user.target steht -> Anaconda-Sperre "kein Kickstart im Live-Modus" in der
               RAM-Kopie aufheben (sed in startup_utils.py) -> Kickstart schreiben -> liveinst im cmdline-Modus (derselbe Weg wie
               der Desktop-Starter: LIVECMD) -> nach dem Ende das Ziel mounten, BLS/GRUB/Denylist zeigen, Anaconda-Logs sichern
               -> poweroff.
Modus disk:    installiertes System von der virtuellen NVMe booten (UEFI-NVRAM aus pflash), als root anmelden, Pruefbefehle mit
               Markern ausfuehren, optional Standardkernel per grubby umschalten, dann poweroff (QEMU -no-reboot beendet sich).

Aufruf: qemu-install.py <logdatei> <timeout_s> <install|disk> [kernel=sl7b] [setdefault=<Kernelversion>] [rootpw=...]
        -- <qemu-Kommandozeile...>
Exit 0 = Erfolg, 1 = Fehler erkannt, 2 = Timeout, 3 = GRUB/Shell/Login nicht erreicht.
Alle Marker: @@RC=<exit>:<schritt> (Ausgabe) - die Tastatur-Echo-Zeile enthaelt "$?" statt einer Zahl und stoert nicht.
"""
import os, re, select, subprocess, sys, time

log_path, timeout, mode = sys.argv[1], int(sys.argv[2]), sys.argv[3]
sep = sys.argv.index('--')
opts = dict(a.split('=', 1) for a in sys.argv[4:sep])
qemu_cmd = sys.argv[sep + 1:]
KERN = opts.get('kernel', 'sl7b')
ROOTPW = opts.get('rootpw', 'sl7test')
SETDEFAULT = opts.get('setdefault', '')
KA, KB, KS = '7.0.0-rc4-sl7', '7.3.0-rc3-sl7b', '6.19.10-300.fc44.aarch64'

# Live-Cmdline wie im echten Bootmenue (LIVE + X1E + NOADSP), plus seriell/Debug-Shell (nicht preserved -> nicht im Zielsystem)
LIVE = ("root=live:CDLABEL=Fedora-KDE-Live-44 rd.live.image clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0 "
        "modprobe.blacklist=qcom_q6v5_pas console=ttyAMA0 rd.timeout=240 plymouth.enable=0 "
        "systemd.debug_shell=ttyAMA0 systemd.mask=serial-getty@ttyAMA0.service")
if KERN == 'stock':
    GRUB_LINES = ["set L=/boot/aarch64/loader", f"linux ($root)$L/linux {LIVE}", "initrd ($root)$L/initrd", "boot"]
else:
    GRUB_LINES = ["set L=/boot/aarch64/loader", f"linux ($root)$L/linux-{KERN} {LIVE}", f"initrd ($root)$L/initrd-{KERN}", "boot"]

BAD_PAT = re.compile(rb"Kernel panic|Entering emergency mode|dracut-initqueue\[\d+\]: Warning: .*(timeout|could not boot)|"
                     rb"Warning: /dev/disk/by-label/Fedora-KDE-Live-44 does not exist|You are in (emergency|rescue) mode", re.I)

KS_LINES = [
    "# SL7-Testinstallation (QEMU): entspricht der Standard-GUI-Installation (autopart btrfs), plus rootpw fuer die serielle Anmeldung",
    "lang de_DE.UTF-8",
    "keyboard --vckeymap=de --xlayouts=de",
    "timezone Europe/Berlin --utc",
    "network --hostname=sl7test",
    f"rootpw --plaintext {ROOTPW}",
    "ignoredisk --only-use=nvme0n1",
    "clearpart --all --initlabel --drives=nvme0n1",
    "autopart --type=btrfs",
    "bootloader --append=\"plymouth.enable=0\"",
]
PYS = "/usr/lib64/python3.14/site-packages/pyanaconda/startup_utils.py"
INSTALL_STEPS = [
    # (schritt, [zeilen], timeout_s)
    (1, ["set +H; dmesg -n 1; echo @@RC=$?:1"], 60),
    (2, ["cat /proc/cmdline; ls -la /dev/mapper/; lsblk -o NAME,SIZE,TYPE,FSTYPE; free -m | head -2; "
         "systemctl is-active livesys.service livesys-late.service multi-user.target; getenforce; echo @@RC=$?:2"], 60),
    (3, [f"grep -c 'options.ksfile and not options.liveinst' {PYS}; "
         f"sed -i 's/if options.ksfile and not options.liveinst:/if options.ksfile:/' {PYS}; "
         f"grep -n 'options.ksfile' {PYS}; echo @@RC=$?:3"], 60),
    (4, ["cat > /root/ks.cfg <<'EOK'"] + KS_LINES + ["EOK", "cat /root/ks.cfg; echo @@RC=$?:4"], 60),
    (5, ["export ANACONDA_LOG_LEVEL=info; LIVECMD='anaconda --liveinst --cmdline --kickstart /root/ks.cfg' /usr/bin/liveinst 2>&1 "
         "| tee /root/liveinst.out; echo @@RC=${PIPESTATUS[0]}:5"], None),
    (6, ["ls /tmp/anaconda-tb-* 2>/dev/null; for f in /tmp/anaconda-tb-*; do [ -f \"$f\" ] && head -150 \"$f\"; done; "
         "grep -nE 'CRIT|ERR|Traceback|CmdlineError|mandatory' /tmp/anaconda.log | tail -20; tail -25 /tmp/anaconda.log; echo @@RC=$?:6"], 120),
    (7, ["lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/nvme0n1; efibootmgr -v 2>&1 | head -12; "
         "mkdir -p /mnt/t; BT=$(lsblk -no PATH,FSTYPE /dev/nvme0n1 | awk '$2==\"btrfs\"{print $1}' | head -1); "
         "EX=$(lsblk -no PATH,FSTYPE /dev/nvme0n1 | awk '$2==\"ext4\"{print $1}' | head -1); "
         "VF=$(lsblk -no PATH,FSTYPE /dev/nvme0n1 | awk '$2==\"vfat\"{print $1}' | head -1); echo \"btrfs=$BT boot=$EX efi=$VF\"; "
         "mount -o subvol=root \"$BT\" /mnt/t && mount \"$EX\" /mnt/t/boot && mount \"$VF\" /mnt/t/boot/efi; echo @@RC=$?:7"], 120),
    (8, ["ls -la /mnt/t/boot/ /mnt/t/boot/loader/entries/ /mnt/t/boot/efi/EFI/fedora/ /mnt/t/boot/efi/EFI/BOOT/; "
         "for f in /mnt/t/boot/loader/entries/*.conf; do echo \"--- $f\"; cat \"$f\"; done; "
         "echo '--- grubenv'; cat /mnt/t/boot/grub2/grubenv | grep -v '^#'; echo '--- efi grub.cfg'; cat /mnt/t/boot/efi/EFI/fedora/grub.cfg; "
         "echo '--- denylist'; cat /mnt/t/etc/modprobe.d/anaconda-denylist.conf; echo '--- fstab'; grep -v '^#' /mnt/t/etc/fstab; "
         "echo '--- kernel cmdline datei'; cat /mnt/t/etc/kernel/cmdline 2>&1; echo '--- vmlinuz vs dtbloader'; "
         f"for K in {KA} {KB}; do cmp /mnt/t/boot/vmlinuz-$K /mnt/t/lib/modules/$K/vmlinuz-dtbloader.efi && echo \"vmlinuz-$K == dtbloader-Image\"; done; "
         "ls -la /mnt/t/boot/initramfs-*; echo @@RC=$?:8"], 180),
    (9, ["mkdir -p /mnt/t/root/sl7-install-logs; cp /tmp/anaconda.log /tmp/storage.log /tmp/program.log /tmp/packaging.log /tmp/dbus.log "
         "/tmp/anaconda-tb-* /root/liveinst.out /root/ks.cfg /mnt/t/root/sl7-install-logs/ 2>/dev/null; ls /mnt/t/root/sl7-install-logs/; "
         "ls /mnt/t/var/log/anaconda/ 2>&1 | head; grep -c . /mnt/t/var/log/anaconda/anaconda.log 2>&1; "
         "grep -nE 'kernel-install|grub2-mkconfig|dracut|efibootmgr' /tmp/program.log | cut -c1-150 | tail -25; "
         "sync; umount -R /mnt/t; echo @@RC=$?:9"], 300),
]
DISK_STEPS = [
    (1, ["set +H; echo @@RC=$?:1"], 30),
    (2, ["uname -r; cat /proc/cmdline; cat /sys/firmware/devicetree/base/model; echo; systemctl is-system-running; "
         "systemctl --failed --no-legend --no-pager; getenforce; hostname; echo @@RC=$?:2"], 120),
    (3, ["ls /boot/loader/entries/; grubby --default-kernel; grubby --info=ALL 2>/dev/null | grep -E '^(index|kernel|args|title)' | cut -c1-200; "
         "grub2-editenv list; efibootmgr -v 2>&1 | head -12; echo @@RC=$?:3"], 120),
    (4, ["systemctl status sl7-postinstall.service --no-pager -l 2>&1 | head -14; echo '--- postinstall.log'; cat /var/lib/sl7/postinstall.log 2>&1; "
         "echo '--- modprobe.d'; ls -la /etc/modprobe.d/; cat /etc/modprobe.d/anaconda-denylist.conf 2>&1; echo @@RC=$?:4"], 120),
    (5, ["ls -la /boot/vmlinuz-* /boot/initramfs-*; for K in $(ls /lib/modules); do echo \"--- initramfs $K: spi-hid=$(lsinitrd /boot/initramfs-$K.img 2>/dev/null | grep -c 'spi-hid') "
         "qcadsp=$(lsinitrd /boot/initramfs-$K.img 2>/dev/null | grep -c qcadsp8380) board2=$(lsinitrd /boot/initramfs-$K.img 2>/dev/null | grep -c 'updates/ath12k') "
         "efi_pstore=$(lsinitrd /boot/initramfs-$K.img 2>/dev/null | grep -c 'efi.pstore')\"; done; "
         f"for K in {KA} {KB}; do cmp /boot/vmlinuz-$K /lib/modules/$K/vmlinuz-dtbloader.efi && echo \"vmlinuz-$K == dtbloader-Image\"; done; echo @@RC=$?:5"], 600),
    (6, ["rpm -q iptsd kernel kernel-uki-dtbloader sl7-mac 2>&1; grep -v '^#' /etc/dnf/dnf.conf; systemctl list-unit-files --no-pager --no-legend | grep -E 'iptsd|sl7'; "
         "ls /etc/iptsd.d/ /etc/modules-load.d/ /etc/dracut.conf.d/; ls /usr/lib/firmware/updates/qcom/x1e80100/microsoft/ | head; ls /usr/lib/firmware/updates/ath12k/WCN7850/hw2.0/; echo @@RC=$?:6"], 120),
    (7, ["journalctl -b -p err --no-pager 2>&1 | tail -25; echo \"--- AVC-Zaehler: $(journalctl -b --no-pager 2>/dev/null | grep -c 'avc: ')\"; "
         "journalctl -b --no-pager 2>/dev/null | grep 'avc: ' | cut -c1-200 | head -8; echo @@RC=$?:7"], 180),
    (8, ["df -h / /boot /boot/efi; btrfs subvolume list / 2>&1; grep -v '^#' /etc/fstab; ls /var/log/anaconda/ /root/sl7-install-logs/ 2>&1; "
         "systemctl status sddm --no-pager 2>&1 | head -5; systemctl is-active graphical.target; echo @@RC=$?:8"], 120),
    (9, ["echo '--- restorecon -n (Label-Abweichungen, sollte leer sein):'; restorecon -nvR /etc /usr/lib/systemd /usr/lib/sl7 /var/lib /boot /root 2>/dev/null | head -20; "
         "echo '--- Zeilen gesamt:'; restorecon -nvR /etc /usr /var /boot 2>/dev/null | wc -l; echo @@RC=$?:9"], 900),
]

log = open(log_path, 'wb')
p = subprocess.Popen(qemu_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
buf = b''; base = 0; start = time.time(); eof = False   # base = absolute Position von buf[0] (Puffer wird gekuerzt)

def abs_len():
    return base + len(buf)

def note(msg):
    line = f"\n[qemu-install {int(time.time()-start):5d}s] {msg}\n".encode()
    log.write(line); log.flush(); print(msg, flush=True)

def send(s):
    try:
        p.stdin.write(s.encode()); p.stdin.flush()
    except (BrokenPipeError, OSError):
        pass

def pump(wait=1.0):
    """liest verfuegbare Ausgabe (max. wait s) in buf/log; gibt False bei EOF."""
    global buf, eof, base
    r, _, _ = select.select([p.stdout], [], [], wait)
    if r:
        chunk = os.read(p.stdout.fileno(), 65536)
        if not chunk:
            eof = True; return False
        log.write(chunk); log.flush(); buf += chunk
        if len(buf) > 4_000_000:
            base += len(buf) - 1_000_000; buf = buf[-1_000_000:]
    return True

def expect(patterns, t, bad=BAD_PAT, since=None):
    """wartet bis t s auf eines der Muster (bytes-Regex-Liste) im Puffer ab absoluter Position since. Rueckgabe (index, match)
    oder (-1, None) bei Timeout, (-2, m) bei BAD, (-3, None) bei EOF."""
    if since is None: since = abs_len()
    deadline = time.time() + t
    while time.time() < deadline and time.time() - start < timeout:
        pump(1.0)
        if eof: return -3, None
        seg = buf[max(0, since - base):]
        for i, pat in enumerate(patterns):
            m = pat.search(seg)
            if m: return i, m
        if bad is not None:
            m = bad.search(seg)
            if m: return -2, m
    return -1, None

def run_step(step, lines, t, prompt_wait=0.4):
    """sendet Zeilen, wartet auf @@RC=<n>:<step>. Rueckgabe rc (int) oder None bei Timeout/EOF."""
    pos = abs_len()
    for ln in lines:
        send(ln + '\r'); time.sleep(prompt_wait)
    pat = re.compile(rb"@@RC=(\d+):%d\b" % step)
    i, m = expect([pat], t if t else timeout, bad=None, since=pos)
    if i == 0:
        rc = int(m.group(1)); note(f"Schritt {step}: rc={rc}"); return rc
    note(f"Schritt {step}: kein Marker (i={i})"); return None

def boot_from_grub():
    i, _ = expect([re.compile(rb"SL7:|Start Fedora-KDE|GNU GRUB")], 420, bad=None)
    if i != 0: note("GRUB-Menue nicht gesehen"); return False
    time.sleep(1.0)
    for attempt in range(3):
        pos = abs_len(); send('c')
        i, _ = expect([re.compile(rb"grub>")], 20, bad=None, since=pos)
        if i == 0: break
    else:
        note("grub>-Prompt nicht erreicht"); return False
    for ln in GRUB_LINES:
        send(ln + '\r'); time.sleep(0.8)
    note("GRUB-Befehle gesendet: " + " ; ".join(GRUB_LINES)); return True

def wait_debug_shell():
    """pollt die Debug-Shell, bis sie im echten Root laeuft (multi-user.target aktiv) - die Initramfs-Shell antwortet 'inactive'."""
    deadline = time.time() + 900; last = 0; pos = abs_len()
    while time.time() < deadline and time.time() - start < timeout:
        if time.time() - last > 10:
            send("\recho @@RE''ADY:$(systemctl is-active multi-user.target 2>&1 | head -1)\r"); last = time.time()
        pump(1.0)
        if eof: return False
        seg = buf[max(0, pos - base):]
        if re.search(rb"\n@@READY:active", seg): return True
        m = BAD_PAT.search(seg)
        if m: note("FEHLER im Boot: " + m.group(0).decode(errors='replace')); return False
        if len(seg) > 1_500_000: pos = abs_len() - 200_000
    return False

result = 2
try:
    if mode == 'install':
        if not boot_from_grub():
            result = 3
        elif not wait_debug_shell():
            note("Debug-Shell im Live-System nicht erreicht"); result = 3
        else:
            note("Debug-Shell bereit (multi-user.target aktiv)")
            rcs = {}
            for step, lines, t in INSTALL_STEPS:
                rcs[step] = run_step(step, lines, t)
                if rcs[step] is None: break
                if step == 3 and rcs[step] != 0: note("sed-Patch fehlgeschlagen"); break
                if step == 5:
                    note(f"liveinst beendet mit rc={rcs[step]}")
            ok = rcs.get(5) == 0 and rcs.get(7) == 0 and rcs.get(8) == 0 and rcs.get(9) == 0
            send("sync; poweroff\r")
            expect([re.compile(rb"reboot: Power down|Power down")], 180, bad=None)
            result = 0 if ok else 1
            note(f"Ergebnis install: rcs={rcs} -> {'ERFOLG' if ok else 'FEHLER'}")
    elif mode == 'disk':
        i, m = expect([re.compile(rb"\n[\w.-]+ login: ")], 900)
        if i == -2:
            note("FEHLER im Boot: " + m.group(0).decode(errors='replace')); result = 1
        elif i != 0:
            note("Login-Prompt nicht erreicht"); result = 3
        else:
            pos = abs_len(); send("root\r")
            i, _ = expect([re.compile(rb"Password: ?")], 30, bad=None, since=pos)
            if i != 0:
                note("Passwortabfrage fehlt"); result = 3
            else:
                pos = abs_len(); send(ROOTPW + "\r")
                i, _ = expect([re.compile(rb"\]# |Login incorrect")], 60, bad=None, since=pos)
                if i != 0 or b"Login incorrect" in buf[max(0, pos - base):]:
                    note("Anmeldung fehlgeschlagen"); result = 3
                else:
                    note("als root angemeldet")
                    rcs = {}
                    for step, lines, t in DISK_STEPS:
                        rcs[step] = run_step(step, lines, t)
                        if rcs[step] is None: break
                    if SETDEFAULT:
                        rcs[10] = run_step(10, [f"grubby --set-default=/boot/vmlinuz-{SETDEFAULT}; grubby --default-kernel; echo @@RC=$?:10"], 60)
                    ok = all(v is not None for v in rcs.values()) and rcs.get(2) is not None
                    send("sync; systemctl poweroff\r")
                    expect([re.compile(rb"reboot: Power down|Power down")], 180, bad=None)
                    result = 0 if ok else 1
                    note(f"Ergebnis disk: rcs={rcs} -> {'ERFOLG' if ok else 'FEHLER'}")
    else:
        note("unbekannter Modus"); result = 3
    if time.time() - start >= timeout: note("TIMEOUT"); result = 2
finally:
    try: p.kill()
    except Exception: pass
    log.close()
sys.exit(result)
