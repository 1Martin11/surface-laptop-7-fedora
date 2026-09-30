export const meta = {
  name: 'sl7-synthese',
  description: 'Synthese des SL7-Linux-Dossiers aus dem gespeicherten Recherche-Korpus und den lokal verifizierten Build-Fakten: Entwurf, Luecken-Kritik, max. 3 Nachrecherchen, finale Dateien',
  phases: [
    { title: 'Entwurf', detail: 'Dossier-Entwurf aus corpus.md + local-facts.md' },
    { title: 'Kritik', detail: 'Luecken finden, max. 3 gezielte Web-Nachrecherchen' },
    { title: 'Final', detail: 'Dossier, Build-Rezept, Offene Punkte schreiben' },
  ],
}

const today = args.today
const corpus = args.corpusPath
const facts = args.factsPath
const outDir = args.outDir
const draftPath = args.draftPath

const GAPS = { type: 'object', properties: { gaps: { type: 'array', items: { type: 'object', properties: { question: { type: 'string' }, why: { type: 'string' }, search_hints: { type: 'string' } }, required: ['question', 'why'] } } }, required: ['gaps'] }
const FINDINGS = { type: 'object', properties: { topic: { type: 'string' }, summary: { type: 'string' }, facts: { type: 'array', items: { type: 'object', properties: { claim: { type: 'string' }, source: { type: 'string' }, source_date: { type: 'string' }, confidence: { type: 'string', enum: ['high', 'medium', 'low'] } }, required: ['claim', 'source', 'confidence'] } }, recommendations: { type: 'array', items: { type: 'string' } }, sources: { type: 'array', items: { type: 'string' } } }, required: ['topic', 'summary', 'facts', 'recommendations', 'sources'] }
const FINAL = { type: 'object', properties: { files: { type: 'array', items: { type: 'string' } }, kernel_decision: { type: 'string' }, build_recipe_short: { type: 'string' }, top_open_issues: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['files', 'kernel_decision', 'build_recipe_short', 'summary'] }

const ctx = 'PROJECT: Linux at 100% on a Microsoft Surface Laptop 7 13.8 inch Snapdragon X Elite (Qualcomm X1E80100, codename Romulus13). Owner Martin (German, hands-on hobbyist) builds the kernel on an x86 Windows PC in WSL2 and installs on the laptop. Today is ' + today + '. ' +
  'INPUT FILES (read them completely with the Read tool, in chunks with offset/limit if needed): (1) "' + corpus + '" = research corpus, 7 topics with facts/sources and, for 4 topics, a skeptical verification block (apply every CORRECTED/REFUTED verdict; the verifier wins over the researcher when it cites 2026 evidence). (2) "' + facts + '" = locally verified facts from the build host (authoritative; they override web claims where they conflict). '

phase('Entwurf')
const draftSummary = await agent(ctx +
  'TASK: write the complete German project dossier "Projekt Linux – Surface Laptop 7 13.8\" X Elite (Romulus13)" as Markdown to the file "' + draftPath + '" using the Write tool (no web tools needed). Structure: ' +
  '1 Ziel & Ausgangslage (what exists locally: ISOs, community repos, scripts, built artefacts); 2 Hardware-Inventar (table Komponente | Chip | Kernel-Treiber | Firmware | Status Linux, plus notes; include ports, display, battery, EC/SAM, sensors, TPM); 3 Kernel-Entscheidung (why ELLX 7.0.0-rc4-12 as base, the full patch list with origin/date/status, cmdline, config highlights, the stubble/DTB mechanism, alternatives 7.2 concept / mainline / jhovold and when to switch); 4 Firmware (table Datei | Quelle | Zielpfad | Zweck; MSI URL/version; what the MSI contains beyond that; ath12k board-2.bin root cause + fix; Bluetooth; GPU zap); 5 Distro-Empfehlung & Installationsablauf (ranked: Ubuntu 26.04.1 arm64 + own kernel vs concept ISO vs ELLX ISO vs Fedora/Arch/NixOS; step by step: Windows prep/BitLocker/shrink, Surface UEFI settings, Ventoy, install, then sl7-install-on-laptop.sh; what to check after first boot; recovery/fallback); 6 Komponenten-Status & Fixes (table + per-component details: Wi-Fi, BT, GPU, display/backlight, audio with the SPEAKER-DAMAGE warning as a boxed warning, mic, camera, touchpad/iptsd incl. systemd/udev + calibration + SIGILL note, touchscreen (both DT variants, experimental), keyboard/SAM, suspend (deep, power button), battery/charging, USB-C/DP/USB4 limits, RTC, thermals/fan, MAC addresses, KVM); 7 Optimierung (cpufreq SCMI/boost, governor, TLP/ppd, thermals, GPU stack Mesa/turnip versions + kisak PPA, video decode iris, Wayland/scaling GNOME vs KDE, page size decision 4K, zram, filesystem, boot time, FEX/box64/Steam/Widevine, kernel config fine-tuning for the next build); 8 Build-Rezept WSL2 (exact commands in order, referencing the local scripts by path, plus what each does; firmware extraction; stubble; chroot test; install on target; fallback boot; rebuild after changes); 9 Offene Punkte & Risiken (ordered by severity); 10 Quellen (every URL with date, grouped). ' +
  'Rules: German language, precise, no invented facts; mark items "(unverifiziert)" when only single-source or contradicted; keep every URL from the corpus that you rely on; tables where useful; the document may be long (this is the master reference). After writing, return a 10-line summary of what the dossier contains and any contradictions you had to resolve.',
  { label: 'entwurf', phase: 'Entwurf' })

phase('Kritik')
const critique = await agent(
  'You are a completeness critic (no web tools). Today is ' + today + '. Owner goal: 100% working Linux on the Surface Laptop 7 13.8 X Elite (romulus13) with a self-built kernel, no hardware damage. Read the draft "' + draftPath + '" completely (chunks) and the facts file "' + facts + '". ' +
  'List the max. 3 most important gaps that a short web research (15 tool calls) can still close before the owner starts: decision-critical unverified claims, missing versions/URLs, contradictions, safety gaps. Each gap concrete and researchable. If nothing decision-critical is missing, return fewer gaps.',
  { label: 'kritik', phase: 'Kritik', schema: GAPS })
const gapList = (critique && critique.gaps ? critique.gaps : []).filter(g => !/i2c8|fQwQf/.test(g.question)).slice(0, 2)   // Budget: Touchscreen-Bus-Frage entfaellt (beide DT-Varianten sind gebaut)
log('Luecken: ' + gapList.length)

const gapResults = await pipeline(gapList, (g, _i, idx) => agent(
  ctx + 'GAP RESEARCH #' + (idx + 1) + ': ' + g.question + '\nWhy: ' + g.why + '\nHints: ' + (g.search_hints || '') +
  '\nHARD BUDGET: max 15 tool calls (load web tools first: ToolSearch "select:WebSearch,WebFetch"). Prefer 2026 primary sources, state dates. Return structured findings.',
  { label: 'nachrecherche:' + (idx + 1), phase: 'Kritik', schema: FINDINGS }))

phase('Final')
const final = await agent(ctx +
  'TASK (no web tools): read the draft "' + draftPath + '" completely and integrate the GAP RESEARCH below (apply corrections, add facts and URLs). Then WRITE with the Write tool:\n' +
  '1) "' + outDir + '\\SL7-Linux-Dossier.md" — the complete final dossier (all 10 sections, German, every URL with date).\n' +
  '2) "' + outDir + '\\Build-Rezept.md" — only the executable recipe: prerequisites, the local scripts in order (wsl-setup-toolchain.sh, wsl-setup-multiarch.sh, wsl-clone-kernels.sh, wsl-build-kernel.sh with PKGREV, wsl-apply-extra-patches.sh, wsl-build-stubble.sh, wsl-extract-firmware.sh with MSI_URL, wsl-arm64-chroot.sh + chroot tests), how to run them from PowerShell (wsl -d Ubuntu -u root -- bash "/mnt/c/.../script.sh"), what to copy to the USB stick, sl7-install-on-laptop.sh on the target, verification commands after boot (uname, dmesg greps, /sys checks for cpufreq/GPU/Wi-Fi/touch), how to rebuild after a patch change, how to switch to the 7.2 concept base later. Bash code blocks in order with short German comments.\n' +
  '3) "' + outDir + '\\Offene-Punkte.md" — checklist: risks (speaker damage first), experimental items (touchscreen variants, USB PHY fix, dwc3), unverified claims, next steps (e.g. run hardware dump on the Surface, test-boot order, measurements to take), ordered by severity.\n' +
  'Use exactly these Windows paths (directory exists). Then return the structured summary.\n\nGAP RESEARCH:\n' + JSON.stringify(gapResults.filter(Boolean), null, 1),
  { label: 'final', phase: 'Final', schema: FINAL })

return { final, draftSummary, gaps: gapList.map(g => g.question) }
