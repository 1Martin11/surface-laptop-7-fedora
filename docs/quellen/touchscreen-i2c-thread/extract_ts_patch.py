import re, html, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
s = open('ts-thread.html', encoding='utf-8', errors='replace').read()
# <pre> blocks carry the mail bodies on the lore-style mirror
pres = re.findall(r'<pre[^>]*>(.*?)</pre>', s, flags=re.S)
print("pre-Bloecke:", len(pres))
n = 0
for p in pres:
    t = html.unescape(re.sub(r'<[^>]+>', '', p))
    if 'diff --git' not in t:
        continue
    n += 1
    m = re.search(r'Subject:\s*(.*)', t)
    subj = m.group(1).strip() if m else 'unbekannt'
    print("\n=== Mail", n, "|", subj[:100])
    # keep everything from first header line to end of diff
    start = t.find('diff --git')
    hdr = t[:start]
    body = t[start:]
    # strip trailing signature / footer after the last hunk
    body = re.sub(r'\n--\s*\n2\.\d+.*$', '\n', body, flags=re.S)
    fname = 'romulus13-touchscreen-%d.patch' % n
    with open(fname, 'w', encoding='utf-8', newline='\n') as f:
        f.write('Subject: ' + subj + '\n\n' + hdr[-1200:].strip() + '\n\n' + body.rstrip() + '\n')
    print(body[:3000])
    print("-> geschrieben:", fname, len(body), "Zeichen")
