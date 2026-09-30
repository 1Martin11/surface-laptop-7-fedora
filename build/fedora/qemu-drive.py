#!/usr/bin/env python3
"""Treibt qemu-system-aarch64 (-nographic) ueber die serielle Konsole: wartet auf das GRUB-Menue des SL7-ISO,
oeffnet die GRUB-Kommandozeile (c) und bootet den gewuenschten Kernel mit serieller Konsole. Danach wird die
Ausgabe bis zum Login/graphical.target (Erfolg) oder Panic/Emergency (Fehler) mitgeschnitten.

Aufruf: qemu-drive.py <logdatei> <timeout_s> <kernel: sl7a|sl7b|stock> -- <qemu-Kommandozeile...>
Exit 0 = Erfolg, 1 = Fehler erkannt, 2 = Timeout, 3 = GRUB nicht erreicht.
"""
import os, re, select, subprocess, sys, time

log_path, timeout, kern = sys.argv[1], int(sys.argv[2]), sys.argv[3]
qemu_cmd = sys.argv[sys.argv.index('--') + 1:]
LIVE = "root=live:CDLABEL=Fedora-KDE-Live-44 rd.live.image console=ttyAMA0 systemd.show_status=1 clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0 rd.timeout=240 plymouth.enable=0"
if kern == 'stock':
    grub_lines = ["set L=/boot/aarch64/loader", f"linux ($root)$L/linux {LIVE}", "initrd ($root)$L/initrd", "boot"]
else:
    grub_lines = ["set L=/boot/aarch64/loader", f"linux ($root)$L/linux-{kern} {LIVE}", f"initrd ($root)$L/initrd-{kern}", "boot"]

OK_PAT = re.compile(rb"Reached target.*(Graphical Interface|graphical\.target)|Fedora Linux 44.*login:|\n[\w-]+ login: |Started.*(Simple Desktop Display Manager|sddm)|Startup finished in", re.I)
BAD_PAT = re.compile(rb"Kernel panic|dracut-initqueue\[\d+\]: Warning: .*(timeout|could not boot)|Entering emergency mode|Warning: /dev/disk/by-label/Fedora-KDE-Live-44 does not exist|end Kernel panic", re.I)

VENTOY = bool(os.environ.get('SL7_VENTOY'))   # Ventoy-Kette: erst Ventoys GRUB, dann unseres
log = open(log_path, 'wb')
p = subprocess.Popen(qemu_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
buf = b''; start = time.time(); state = 'wait_menu'; sent_at = 0; result = 2; last_len = 0

def send(s):
    p.stdin.write(s.encode()); p.stdin.flush()

try:
    while time.time() - start < timeout:
        r, _, _ = select.select([p.stdout], [], [], 1.0)
        if r:
            chunk = os.read(p.stdout.fileno(), 65536)
            if not chunk:
                break
            log.write(chunk); log.flush(); buf += chunk
            if len(buf) > 2_000_000: buf = buf[-500_000:]
        if state == 'wait_menu':
            if b'SL7:' in buf or (not VENTOY and (b'Start Fedora-KDE' in buf or b'GNU GRUB' in buf)):
                time.sleep(1.0); send('c'); state = 'wait_prompt'; sent_at = time.time(); last_len = len(buf)
            elif VENTOY and time.time() - start > 60 and time.time() - sent_at > 20:
                send(chr(13)); sent_at = time.time()   # Ventoy-Menue/Hinweis bestaetigen, falls der Timeout nicht greift
        elif state == 'wait_prompt':
            if b'grub>' in buf[last_len:]:
                for line in grub_lines:
                    send(line + '\r'); time.sleep(0.8)
                state = 'booting'; sent_at = time.time()
                log.write(b'\n[qemu-drive] GRUB-Befehle gesendet: ' + '; '.join(grub_lines).encode() + b'\n')
            elif time.time() - sent_at > 20:
                send('c'); sent_at = time.time()
        elif state == 'booting':
            if OK_PAT.search(buf):
                result = 0; log.write(b'\n[qemu-drive] ERFOLG erkannt\n'); break
            if BAD_PAT.search(buf):
                result = 1; log.write(b'\n[qemu-drive] FEHLER erkannt\n'); time.sleep(8); break
            if b'error:' in buf[last_len:] and time.time() - sent_at > 5 and b'Linux version' not in buf:
                result = 3; log.write(b'\n[qemu-drive] GRUB-Fehler\n'); break
    else:
        log.write(b'\n[qemu-drive] TIMEOUT\n')
    if state == 'wait_menu': result = 3
finally:
    try: p.kill()
    except Exception: pass
    log.close()
sys.exit(result)
