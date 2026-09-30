#!/usr/bin/env python3
"""SSH-Helfer fuers Surface (Live-System): sl7-ssh.py <host> <pwdatei> [--out DATEI] BEFEHL [BEFEHL...]
Jeder Befehl laeuft als root (sudo -S, Passwort aus Datei, nie auf der Kommandozeile). Ausgabe mit Trennzeilen, optional in Datei."""
import sys, paramiko
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
host, pwfile = sys.argv[1], sys.argv[2]; args = sys.argv[3:]; out = None; user = 'liveuser'
if args and args[0] == '--user': user = args[1]; args = args[2:]
if args and args[0] == '--out': out = open(args[1], 'w', encoding='utf-8', newline='\n'); args = args[2:]
pw = open(pwfile).read().strip()
c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(host, username=user, password=pw, timeout=20, look_for_keys=False, allow_agent=False)
import base64
puts = []
while args and args[0] == '--put':          # --put LOKAL ENTFERNT: Datei base64-kodiert per Befehlskanal schreiben (als root)
    b64 = base64.b64encode(open(args[1], 'rb').read()).decode(); puts.append(f"echo {b64} | base64 -d > {args[2]} && echo '[put] {args[2]}'"); args = args[3:]
args = puts + args
for cmd in args:
    stdin, stdout, stderr = c.exec_command("sudo -S -p '' bash -c " + "'" + cmd.replace("'", "'\"'\"'") + "'" + " 2>&1", timeout=300)
    stdin.write(pw + '\n'); stdin.flush()
    txt = stdout.read().decode(errors='replace')
    block = f"\n===== {cmd}\n{txt.rstrip()}\n"
    print(block, flush=True)
    if out: out.write(block)
c.close()
