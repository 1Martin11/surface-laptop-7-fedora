export const meta = {
  name: 'sl7-linux-recherche-v3',
  description: 'Recherche Linux auf Surface Laptop 7 (X1E80100 Romulus13) in Batches mit Tool-Budget: Hardware, Kernel, Firmware, Distros, Fixes, Optimierung, Build, Launchpad; Verifikation; Dossier',
  phases: [
    { title: 'Recherche', detail: '8 Themen in 2 Batches, max 25 Tool-Aufrufe je Agent' },
    { title: 'Verifikation', detail: 'skeptische Gegenpruefung, max 15 Tool-Aufrufe' },
    { title: 'Synthese', detail: 'Dossier, Luecken-Kritik, Nachrecherche, Final' },
  ],
}

const today = args.today
const readmePath = args.readmePath
const outDir = args.outDir
const dtsDir = args.dtsDir
const localFacts = args.localFacts

const FINDINGS = {
  type: 'object',
  properties: {
    topic: { type: 'string' },
    summary: { type: 'string', description: 'Dense German summary, 300-700 words' },
    facts: { type: 'array', items: { type: 'object', properties: {
      claim: { type: 'string' },
      source: { type: 'string' },
      source_date: { type: 'string' },
      confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    }, required: ['claim', 'source', 'confidence'] } },
    recommendations: { type: 'array', items: { type: 'string' } },
    open_questions: { type: 'array', items: { type: 'string' } },
    sources: { type: 'array', items: { type: 'string' } },
  },
  required: ['topic', 'summary', 'facts', 'recommendations', 'sources'],
}

const VERIFY = {
  type: 'object',
  properties: {
    checked: { type: 'array', items: { type: 'object', properties: {
      claim: { type: 'string' },
      verdict: { type: 'string', enum: ['confirmed', 'corrected', 'refuted', 'unverifiable'] },
      correction: { type: 'string' },
      evidence: { type: 'string' },
    }, required: ['claim', 'verdict'] } },
    additions: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['checked', 'additions'],
}

const GAPS = {
  type: 'object',
  properties: {
    gaps: { type: 'array', items: { type: 'object', properties: {
      question: { type: 'string' }, why: { type: 'string' }, search_hints: { type: 'string' },
    }, required: ['question', 'why'] } },
  },
  required: ['gaps'],
}

const FINAL = {
  type: 'object',
  properties: {
    files: { type: 'array', items: { type: 'string' } },
    kernel_decision: { type: 'string' },
    firmware_msi_url: { type: 'string' },
    build_recipe_short: { type: 'string' },
    top_open_issues: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['files', 'kernel_decision', 'build_recipe_short', 'summary'],
}

const preamble = [
  'CONTEXT: Project goal is running Linux at 100% on a Microsoft Surface Laptop 7, 13.8 inch, Snapdragon X Elite (Qualcomm X1E80100, codename Romulus, DT x1e80100-microsoft-romulus13.dts).',
  'The owner Martin builds the kernel on an x86-64 Windows PC in WSL2 Ubuntu 26.04 (cross-compile, already working) and installs on the laptop. Today is ' + today + '.',
  'HARD BUDGET: at most 25 tool calls in total (each WebSearch or WebFetch counts). Plan them: 5-8 searches, then fetch only the most authoritative pages. When the budget is reached, STOP and return what you have. Prefer sources from 2026 and state the date of each source.',
  'Never answer from memory for things that change (versions, branches, URLs, feature status): verify by fetching. FIRST load web tools: ToolSearch query "select:WebSearch,WebFetch".',
  'Local files you may read with the Read tool (do not count against the budget): community README ' + readmePath + ' ; Romulus device tree sources in ' + dtsDir + ' (x1e80100-microsoft-romulus.dtsi, romulus13.dts).',
  'ALREADY VERIFIED LOCALLY (build on it, do not re-research): ' + localFacts,
  'Your final answer is raw data for a synthesis step. Be precise, cite URLs. Summary in German.',
].join(' ')

const TOPICS = [
  { key: 'hardware', title: 'Hardware-Inventar', prompt:
    'TOPIC: hardware inventory of the Surface Laptop 7 13.8 X Elite (Romulus13) for Linux. Start by READING the local dtsi/dts files (they list: WCD9385 codec, WSA speaker amps, WCN7850 PMU, PS8830 retimers, PTN3222 eUSB repeater, OV02C10 camera on cci1, eDP panel, pcie ports, pmic-glink, backlight, gpio-keys, spi-hid?). Then verify with the web: SoC variants sold in 13.8 (X1E-80-100 vs X1P-64-100), RAM, NVMe model (2230?), panel (2304x1536 120 Hz, vendor), GPU Adreno X1-85, Wi-Fi/BT WCN7850 PCIe ids, audio chain, camera + IR camera, touchscreen and touchpad controllers (HID over SPI, vendor/product 045E:0C77?), keyboard/EC path, USB4 ports, battery Wh, sensors, fan, TPM/Pluton. Table-ready output: component | chip | kernel driver | firmware | source.' },
  { key: 'kernel', title: 'Kernel-Stand & Auswahl', prompt:
    'TOPIC: kernel state for Romulus13 as of today. Verify: (1) mainline: which version added romulus13 dts (git.kernel.org log of arch/arm64/boot/dts/qcom/x1e80100-microsoft-romulus.dtsi) and what landed in 6.19/7.0/7.1 for it; newest mainline release and rc today. (2) jhovold X1E80100 wiki (github.com/jhovold/linux/wiki) current branch/version and feature table. (3) Ubuntu concept kernel: launchpad ~ubuntu-concept repos (resolute qcom-x1e-7.0 = 7.0.0-rc4 packaging 7.0.0-22.22 questing; also +git/linux-qcom-x1 with branches up to v6.16) - which is maintained now and whether Ubuntu 26.04/26.10 official arm64 kernel (linux-qcom-x1e flavour?) exists in the archive. (4) linux-surface project: ARM64/SL7 support? (5) Which community patches are upstreamed by now (spi-hid driver? dwc3 reinit-phy-on-resume? OV02C10 dts? battery duplicate fix?). (6) Kernel cmdline for X1E laptops and why (clk_ignore_unused pd_ignore_unused arm64.nopauth efi=noruntime, cutmem in GRUB). Recommendation: stay on ELLX 7.0.0-rc4-12 or move to newer mainline/jhovold, with reasons.' },
  { key: 'firmware', title: 'Firmware', prompt:
    'TOPIC: firmware for Romulus13. (1) Find the CURRENT Microsoft "Surface Laptop 7 (Snapdragon) drivers and firmware" MSI: the old URL SurfaceLaptop7_ARM_Win11_26100_25.013.35106.0.msi is 404 now; find the Microsoft Download Center page (support.microsoft.com "Download drivers and firmware for Surface" -> Surface Laptop 7th Edition / Surface Laptop (13.8 inch) ARM) and the exact current MSI file name, version, direct download.microsoft.com URL and size. (2) linux-firmware upstream: which qcom/x1e80100 files exist (gen70500_sqe.fw, aop, adsp/cdsp generic) and whether microsoft/Romulus firmware is in linux-firmware now (check the linux-firmware git tree WHENCE or directory qcom/x1e80100/microsoft/). (3) ath12k WCN7850 board-2.bin subsystem-device 1107 vs 3378: root cause and whether linux-firmware/ath12k upstream fixed it (git log of ath12k-firmware WCN7850 board-2.bin in 2025/2026). (4) Bluetooth firmware files for WCN7850 (qca/hmtbtfw20.tlv, hmtnv20.bin) and where they come from. (5) GPU zap shader (qcdxkmsuc8380.mbn / qcdxkmsucpurwa.mbn), which one romulus needs. (6) Correct target paths and .zst handling in Ubuntu.' },
  { key: 'distro', title: 'Distros & Installation', prompt:
    'TOPIC: distro choice and install procedure for Romulus13 today. Verify: (1) Ubuntu: does the official Ubuntu 26.04 LTS (resolute) arm64 desktop ISO boot X1E laptops (Snapdragon X Elite support in official Ubuntu 26.04?) - check ubuntu.com release notes / discourse "Ubuntu on Snapdragon X Elite" and cdimage; what the questing x1e concept ISO (20260314) is; what the ELLX installer ISO surface-laptop-7-20260610.iso is (2.2 GB, README warns about speaker damage). (2) Fedora 44/45 aarch64: X1E80100 enabled in Fedora kernel? any SL7 reports. (3) Arch Linux ARM / archlinux x1e community, Debian 13 arm64, NixOS x1e (github nixos-x1e or similar). (4) Install steps on Surface: UEFI settings (Secure Boot off, boot from USB), BitLocker, partition shrink, Ventoy (keyboard in GRUB issue - root cause), device tree loading in Ubuntu (dtb via GRUB devicetree / /boot/dtb / dtbloader.efi by TravMurav), dual boot, recovery. (5) Give a ranked recommendation.' },
  { key: 'issues', title: 'Komponenten-Status & Fixes', prompt:
    'TOPIC: per-component status and fixes for Romulus13 as of today. Fetch GitHub issues of giantdwarf17/linux-surface-laptop-7 (open+closed, especially #2 audio, #4 camera, #6 bluetooth, #7 suspend, #8 rtc, #11 usb-c display, #13 touchscreen) and the newest comments on launchpad bug 2084951 (last ~60 comments via https://api.launchpad.net/devel/ubuntu-concept/+bug/2084951/messages?ws.size=75&ws.start=<total-75>; first GET https://api.launchpad.net/devel/ubuntu-concept/+bug/2084951 to read message_count). VERY IMPORTANT: investigate the SPEAKER DAMAGE reports (ELLX installer README says enabling sound permanently damaged the right speaker; "regular ubuntu concept will probably still damage your speakers") - what is the mechanism (WSA amplifier without thermal/volume limit? missing speaker protection / wrong UCM gain?), which kernels/configs are affected, and how to stay safe (ALSA UCM limits, blacklist modules, safe volume). Also: touchscreen status, touchpad after suspend, keyboard backlight, fn keys, brightness, ALS, thermals/fan, external display, Surface Connect, RTC, battery, fwupd. Output per component: status, fix, source URL + date.' },
  { key: 'optimierung', title: 'Optimierung & Performance', prompt:
    'TOPIC: optimization of Linux on X1E80100 laptops (Romulus13). Verify with sources: cpufreq/EAS/governor situation on X1E in 7.0 kernels (qcom-cpufreh-hw, boost, cpucp mailbox), reported battery life on Linux vs Windows for X1E laptops in 2026, power-profiles-daemon/tuned/TLP recommendations; Mesa turnip/freedreno status for Adreno X1-85 (Vulkan level, Zink, which Mesa version, Ubuntu 26.04 Mesa version), video decode (Venus / iris) status; Wayland fractional scaling for 2304x1536, KDE vs GNOME; kernel config choices: 4K vs 16K pages on X1E (compatibility with FEX/Chromium/Electron), HZ, PREEMPT, clang LTO benefit; zram/zswap; filesystem; boot time tricks (initramfs firmware, MODULES=dep); x86 compatibility: FEX-Emu 2026 state on Ubuntu arm64, box64, Steam via FEX/muvm, Widevine on ARM Linux; thermal behavior. Concrete settings + package versions + URLs.' },
  { key: 'launchpad', title: 'Launchpad 2084951 Digest (2026)', prompt:
    'TOPIC: digest the NEWEST part of https://bugs.launchpad.net/ubuntu-concept/+bug/2084951 (Surface Laptop 7 on Ubuntu concept). Use the Launchpad API: GET https://api.launchpad.net/devel/ubuntu-concept/+bug/2084951 (read message_count, date_last_updated), then GET https://api.launchpad.net/devel/ubuntu-concept/+bug/2084951/messages?ws.size=75&ws.start=<message_count-150> and the next page, to read roughly the last 150 comments (2026). Extract: current recipes (kernel versions/branches, firmware, boot params), problems (speaker damage!, touchpad, touchscreen, suspend, audio, GRUB/Ventoy), key contributors and their repos/URLs, and anything from June-September 2026. Also list every URL posted in those comments pointing to kernels, firmware or fixes.' },
]

function researchStage(t) {
  return agent(preamble + '\n\n' + t.prompt, { label: 'recherche:' + t.key, phase: 'Recherche', schema: FINDINGS })
}
const SKIP_VERIFY = ['issues', 'optimierung', 'launchpad']   // Budget: Batch 2 ohne Gegenpruefung
function verifyStage(findings, t) {
  if (!findings) return null
  if (SKIP_VERIFY.includes(t.key)) return Promise.resolve({ topic: t.key, title: t.title, findings, verification: null })
  return agent(
    'You are a skeptical fact-checker. Today is ' + today + '. Project: Linux on Surface Laptop 7 13.8 X Elite (X1E80100, romulus13). HARD BUDGET: at most 15 tool calls (WebSearch/WebFetch); load them first via ToolSearch "select:WebSearch,WebFetch". ' +
    'Below are findings on "' + t.title + '". Pick the 6-8 most decision-relevant claims (versions, URLs, branches, file names, feature status, safety issues) and verify each by fetching the primary source. Verdicts: confirmed / corrected / refuted / unverifiable, with evidence URL. Outdated 2024/2025 info presented as current = corrected with the 2026 state. Add up to 4 important missed facts with URLs. Raw data output.\n\nFINDINGS:\n' + JSON.stringify(findings, null, 1),
    { label: 'verify:' + t.key, phase: 'Verifikation', schema: VERIFY }
  ).then(v => ({ topic: t.key, title: t.title, findings, verification: v }))
}

phase('Recherche')
const results = []
const batches = [TOPICS.slice(0, 4), TOPICS.slice(4)]
for (let b = 0; b < batches.length; b++) {
  log('Batch ' + (b + 1) + '/2: ' + batches[b].map(t => t.key).join(', '))
  const r = await pipeline(batches[b], researchStage, verifyStage)
  results.push(...r.filter(Boolean))
  log('Batch ' + (b + 1) + ' fertig: ' + results.length + ' Themen bisher')
}
log('Recherche+Verifikation fertig fuer ' + results.length + '/' + TOPICS.length + ' Themen')

phase('Synthese')
const corpus = JSON.stringify(results, null, 1)

const draft = await agent(
  'You are the lead engineer writing the project dossier "Projekt Linux - Surface Laptop 7 13.8 X Elite (Romulus13)". Today is ' + today + '. No web tools needed. ' +
  'Write a complete German Markdown dossier from the verified corpus below (apply every correction from the verification blocks; if researcher and verifier disagree, prefer the verifier when it cites 2026 evidence, else state the conflict). ' +
  'Locally verified facts to integrate: ' + localFacts + ' ' +
  'ADDITIONAL LOCALLY VERIFIED BUILD/BOOT FACTS (authoritative, override web claims where they conflict): ' + args.localFacts2 + ' ' +
  'Sections: 1 Ziel & Ausgangslage (local ISOs: Ubuntu Concept ISO, Fedora KDE 44 aarch64 + customized SurfaceLaptop7 build, questing-desktop-arm64+x1e.iso; community README; old GRUB scripts; the self-built kernel), 2 Hardware-Inventar (table: Komponente | Chip | Kernel-Treiber | Firmware | Status), 3 Kernel-Entscheidung (tree, tag, version, patches, cmdline, config), 4 Firmware (table file | source | target path; MSI URL/version; ELLX tar contents), 5 Distro-Empfehlung & Installationsablauf (UEFI, Ventoy, DTB, dual boot, recovery), 6 Komponenten-Status & Fixes (table + details; SPEAKER-DAMAGE warning prominently), 7 Optimierung (settings, packages, kernel config, page size, GPU, power), 8 Build-Rezept WSL2 (exact commands incl. the local scripts build/wsl-setup-toolchain.sh, wsl-clone-kernels.sh, wsl-build-kernel.sh; install on target; fallback boot), 9 Offene Punkte & Risiken, 10 Quellen (every URL with date). Mark unverified items "(unverifiziert)". Output ONLY Markdown.\n\nCORPUS:\n' + corpus,
  { label: 'synthese:entwurf', phase: 'Synthese' }
)

const critique = await agent(
  'You are a completeness critic (no web tools). Today is ' + today + '. Owner goal: 100% working Linux on Surface Laptop 7 13.8 X Elite (romulus13), self-built kernel via WSL2 cross-compile, optimized system, no hardware damage. ' +
  'Read the dossier draft and list concrete gaps: decision-critical unverified claims, missing components, missing URLs/versions, contradictions, safety gaps (speakers). Max 6 gaps, each concrete and researchable, ordered by importance.\n\nDRAFT:\n' + draft,
  { label: 'synthese:kritik', phase: 'Synthese', schema: GAPS }
)

const gapList = (critique && critique.gaps ? critique.gaps : []).slice(0, 3)
log('Luecken-Kritik: ' + gapList.length + ' Nachrecherchen')

const gapResults = await pipeline(
  gapList,
  (g, _i, idx) => agent(preamble + '\n\nGAP RESEARCH #' + (idx + 1) + ': ' + g.question + '\nWhy it matters: ' + g.why + '\nHints: ' + (g.search_hints || '') + '\nBudget: max 15 tool calls. Answer with primary sources and dates.', { label: 'nachrecherche:' + (idx + 1), phase: 'Synthese', schema: FINDINGS })
)

const final = await agent(
  'You are the lead engineer finalizing the German project dossier (no web tools needed). Today is ' + today + '. Integrate the GAP RESEARCH into the DRAFT (apply corrections, fill facts, resolve contradictions, keep all URLs), then WRITE these files with the Write tool:\n' +
  '1) "' + outDir + '\\SL7-Linux-Dossier.md" - complete dossier, all 10 sections, German, tables, every source URL with date.\n' +
  '2) "' + outDir + '\\Build-Rezept.md" - executable recipe only: WSL2 setup, clone, config, patches, build (the three local scripts), firmware extraction (current MSI URL, msiextract, board-2.bin fix), install on target, fallback GRUB entry, verification commands; bash code blocks in order with short German comments.\n' +
  '3) "' + outDir + '\\Offene-Punkte.md" - open issues, risks (speaker damage first), unverified claims as a checklist.\n' +
  'Use the exact Windows paths (directory exists). The Build-Rezept must reflect the LOCAL build facts (stubble image, dracut, the local scripts and the target installer sl7-install-on-laptop.sh): ' + args.localFacts2 + '\nThen return the structured summary.\n\nDRAFT:\n' + draft + '\n\nGAP RESEARCH:\n' + JSON.stringify(gapResults.filter(Boolean), null, 1),
  { label: 'synthese:final', phase: 'Synthese', schema: FINAL }
)

return { final, topics: results.map(r => ({ topic: r.topic, nFacts: r.findings.facts.length, nChecked: r.verification ? r.verification.checked.length : 0 })), gaps: gapList.map(g => g.question) }
