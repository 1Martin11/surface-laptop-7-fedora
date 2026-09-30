#!/usr/bin/env bash
# Holt aus dem neuesten ItsLucas-Release die Ubuntu-26.10-Kernelquelle (linux-source deb) und BUILD.json nach /work/sl7/fedora/src.
set -uo pipefail
export LC_ALL=C
S=/work/sl7/fedora/src; mkdir -p "$S"; cd "$S"
J=$(curl -sL --max-time 60 -H "User-Agent: sl7" "https://api.github.com/repos/ItsLucas/surface-laptop-7-ubuntu-kernel/releases?per_page=3")
python3 - "$J" <<'PY' > urls.txt
import json,sys
rels=json.loads(sys.argv[1])
rel=[r for r in rels if r['tag_name'].startswith('ubuntu-7.3')][0]
print("# " + rel['tag_name'])
for a in rel['assets']:
    if a['name'] in ('BUILD.json','SHA256SUMS') or a['name'].startswith('linux-source-'):
        print(a['browser_download_url'])
PY
cat urls.txt
grep -v '^#' urls.txt | while read -r u; do f=$(basename "$u"); [ -s "$f" ] || { echo "lade $f"; curl -sL --fail --retry 3 -o "$f" "$u" || echo "FEHLER $f"; }; done
ls -la
echo "=== BUILD.json (Auszug)"; python3 -c "
import json; d=json.load(open('BUILD.json'))
def show(k,v):
    s=json.dumps(v,ensure_ascii=False); print(' ', k, '=', s[:400])
for k in ['ubuntu_source_version','ubuntu_version','kernel_version','abi','recipe_commit','patch_application','patches','base','source_package','toolchain','config']:
    if k in d: show(k, d[k])
print('  Schluessel:', list(d.keys())[:30])"
echo "=== linux-source deb: Inhalt"; dpkg-deb -c linux-source-*.deb | awk '{print $6, $3}' | grep -vE '/$' | head
