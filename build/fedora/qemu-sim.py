#!/usr/bin/env python3
"""Simulator fuer qemu-install.py: spielt GRUB, Kernel-Boot, Debug-Shell (Initramfs + Root) bzw. Login des installierten Systems
ueber stdin/stdout nach, echo der Eingaben wie ein tty, beantwortet @@RC-Marker. Nur zum Trockentest der Treiberlogik."""
import sys, time, os, re
mode = sys.argv[1]
def out(s): sys.stdout.write(s); sys.stdout.flush()
def readline():
    line = b''
    while True:
        c = os.read(0, 1)
        if not c: sys.exit(0)
        out(c.decode(errors='replace'))          # tty-echo
        if c in (b'\r', b'\n'):
            out('\n'); return line.decode(errors='replace')
        line += c
def shell(prompt, ready_after=0):
    """liest Zeilen; beantwortet Marker; n erste READY-Anfragen mit inactive"""
    n = 0; heredoc = None
    while True:
        out(prompt); line = readline()
        if heredoc:
            if line.strip() == heredoc: heredoc = None
            continue
        m = re.search(r"<<'(\w+)'", line)
        if m: heredoc = m.group(1); out('> ' * 0); continue
        if "@@RE''ADY" in line:
            n += 1; out("@@READY:%s\n" % ("active" if n > ready_after else "inactive")); continue
        for mm in re.finditer(r"echo @@RC=(\$\?|\$\{PIPESTATUS\[0\]\}):(\d+)", line):
            out("[sim] befehl: %s\n" % line[:120]); out("@@RC=0:%s\n" % mm.group(2))
        if line.strip().startswith('grubby --set-default'): out("[sim] grubby\n@@RC=0:10\n")
        if 'poweroff' in line: out("[sim] reboot: Power down\n"); time.sleep(0.5); sys.exit(0)
if mode == 'install':
    out("UEFI firmware...\n"); time.sleep(1); out("GNU GRUB  version 2.12\n SL7: Fedora KDE Live ...\n")
    while True:
        c = os.read(0, 1)
        if c == b'c': break
    out("grub> ")
    for _ in range(4):
        l = readline(); out("grub> ")
    out("Loading kernel...\nLinux version 7.3.0-rc3-sl7b\nMachine model: linux,dummy-virt\n")
    time.sleep(2); out("[    3.1] systemd[1]: Detected virtualization qemu.\n")
    # Initramfs-Debug-Shell: antwortet 2x inactive, dann 'switch root' (Shell endet), neue Shell
    n = 0
    while n < 2:
        out("sh-5.3# "); line = readline()
        if "@@RE''ADY" in line: out("@@READY:inactive\n"); n += 1
    out("[   40.0] systemd[1]: Switching root.\n[   50.0] systemd[1]: Reached target multi-user.target\n")
    shell("sh-5.3# ")
elif mode == 'disk':
    out("UEFI...\nGNU GRUB\nLoading...\nLinux version 7.3.0-rc3-sl7b\n"); time.sleep(1)
    out("\nFedora Linux 44 (KDE Plasma Desktop Edition)\nKernel 7.3.0-rc3-sl7b on an aarch64 (ttyAMA0)\n\nsl7test login: ")
    u = readline(); out("Password: ")
    pw = ''
    while True:
        c = os.read(0, 1)
        if c in (b'\r', b'\n'): break
        pw += c.decode()
    out("\nLast login: never\n"); shell("[root@sl7test ~]# ")
