export const meta = {
  name: 'sl7-fedora-recherche',
  description: 'Recherche fuer ein Fedora-KDE-Live-ISO (aarch64) mit eigenem Kernel fuer den Surface Laptop 7 (X1E80100 Romulus13): Fedora-X1E-Weg, ISO-Remastering, Kernel-RPM, Boot-Loop-Ursachen, haptisches Trackpad, Community-Stand; danach Plan-Synthese',
  phases: [
    { title: 'Recherche', detail: '6 Themen parallel, je max. 20 Web-Aufrufe' },
    { title: 'Plan', detail: 'Synthese zu docs/Fedora-Plan.md' },
  ],
}

const today = args.today
const facts = args.factsPath
const outDir = args.outDir
const localFacts = args.localFacts

const FINDINGS = {
  type: 'object',
  properties: {
    topic: { type: 'string' },
    summary: { type: 'string', description: 'Dichte deutsche Zusammenfassung, 300-700 Woerter' },
    facts: { type: 'array', items: { type: 'object', properties: {
      claim: { type: 'string' }, source: { type: 'string' }, source_date: { type: 'string' },
      confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    }, required: ['claim', 'source', 'confidence'] } },
    recommendations: { type: 'array', items: { type: 'string' } },
    open_questions: { type: 'array', items: { type: 'string' } },
    sources: { type: 'array', items: { type: 'string' } },
  },
  required: ['topic', 'summary', 'facts', 'recommendations', 'sources'],
}

const preamble = [
  'CONTEXT: Goal is a bootable, installable Fedora KDE Plasma Live ISO (aarch64) for the Microsoft Surface Laptop 7 13.8" Snapdragon X Elite (Qualcomm X1E80100, DT x1e80100-microsoft-romulus13) with everything working out of the box: Wi-Fi, Bluetooth, GPU, the haptic trackpad (no mechanical button, click is force-sensed), keyboard, battery, suspend.',
  'The owner Martin builds on an x86 Windows PC in WSL2 Ubuntu 26.04 (cross toolchain, arm64 qemu-user chroot available). A previous attempt (Ubuntu 26.04 + self-built kernel installed on top) ended in a boot loop after the Ubuntu logo; no logs were captured.',
  'Today is ' + today + '. Prefer 2026 sources, state dates. Never answer from memory for versions, URLs, feature status: fetch and verify.',
  'HARD BUDGET: at most 20 tool calls (WebSearch/WebFetch). Load them first: ToolSearch "select:WebSearch,WebFetch". Plan searches, fetch only authoritative pages, stop at the budget and return what you have.',
  'ALREADY KNOWN (do not re-research): ' + localFacts,
  'Your answer is raw data for a planning step. Summary in German, claims and sources verbatim.',
].join(' ')

const TOPICS = [
  { key: 'fedora-x1e', prompt: 'TOPIC: Fedora on Snapdragon X Elite laptops in 2026. Verify: (1) Fedora Wiki "Snapdragon WoA Laptop Install" current content (which release, which laptops, exact steps, kernel cmdline, how the DTB is provided: dtbloader.efi in the ESP? grub devicetree? kernel-install?); (2) Fedora 44 and 45 kernel versions and X1E80100 support state (kernel-6.19/7.0/7.1/7.2 in updates; are the microsoft romulus DTBs shipped in kernel-core /usr/lib/modules/<ver>/dtb/qcom/?); (3) any Fedora-based community images or SIG for X1E (search: "Fedora X1E", "fedora snapdragon x elite image", "Fedora Asahi"-like efforts for Snapdragon, copr repos with x1e kernels); (4) Surface Laptop 7 specific Fedora reports (Reddit, Fedora discussion, GitHub); (5) linux-firmware in Fedora: does it ship ath12k WCN7850 and qcom/x1e80100 blobs, and where do device-specific Microsoft blobs go (/usr/lib/firmware/updates?).' },
  { key: 'iso-remaster', prompt: 'TOPIC: how to remaster a Fedora 44 KDE Live ISO (aarch64) with a custom kernel and extra files, and make the Anaconda live installation keep everything. Verify with primary sources (Fedora docs, lorax/livemedia-creator docs, anaconda docs, dracut docs): (1) exact layout of a Fedora 44 aarch64 Live ISO (EFI/BOOT/*.efi, boot/grub2/grub.cfg, images/pxeboot/vmlinuz+initrd.img, LiveOS/squashfs.img and whether it contains rootfs.img (ext4 inside squashfs) or a plain squashfs; images/efiboot.img); (2) the supported way to inject a kernel: chroot into the rootfs, dnf/rpm install kernel, run dracut with dmsquash-live modules to rebuild the live initrd, repack squashfs (mksquashfs options Fedora uses), rebuild the ISO with xorriso keeping EFI boot (or use mkksiso / livemedia-creator --iso-only); (3) how Anaconda installs from a live image (copies rootfs via rsync/blockcopy, then runs kernel-install/grub2-mkconfig, blscfg) and how to make the installed system use the custom kernel and a devicetree (BLS entry "devicetree" key support in grub2 blscfg; kernel-install 90-loaderentry devicetree handling; grubby --devtree; /etc/kernel/cmdline); (4) Secure Boot: shim + unsigned kernel on Fedora aarch64 requires Secure Boot off or MOK enrollment (mokutil) - what is the practical path; (5) tooling available on an Ubuntu x86 host for the remaster (squashfs-tools, xorriso, qemu-user chroot into the Fedora rootfs, rpm/dnf on Ubuntu).' },
  { key: 'kernel-rpm', prompt: 'TOPIC: building a Fedora-compatible kernel package for aarch64 from a custom kernel tree (Ubuntu concept/ELLX 7.0-rc4 tree or mainline 7.2/7.3 + SL7 patches) on an x86 host by cross-compiling. Verify: (1) make binrpm-pkg / rpm-pkg with ARCH=arm64 CROSS_COMPILE (scripts/package/mkspec, kernel.spec in Linux 7.x): produced packages (kernel, kernel-headers, kernel-devel), file layout (/lib/modules/<ver>, /boot/vmlinuz-<ver>, System.map, config), whether DTBs are installed (dtbs_install into /lib/modules/<ver>/dtb? or /boot/dtb-<ver>?), and the %post script (does it run kernel-install / dracut / new-kernel-pkg?); (2) differences to Fedora kernel-core packaging that matter for booting (kernel-install BLS entries, dracut config, /usr/lib/modules/<ver>/vmlinuz location in Fedora, the "installkernel" hook); (3) alternative: rebuild Fedora kernel SRPM with extra patches in an aarch64 chroot/mock (time cost) vs cross with fedpkg (not supported?); (4) the 7.x kernel EFI zboot image (vmlinuz.efi) and Fedora grub2 compatibility; (5) how UKIs work on Fedora aarch64 (kernel-uki-virt, ukify, systemd-boot vs grub2 with blscfg) and whether embedding DTBs via ukify --devicetree-auto (stubble-like) is usable on Fedora (grub2 "linux" loading a UKI PE with .dtbauto; systemd-stub dtbauto support since v254/257).' },
  { key: 'bootloop', prompt: 'TOPIC: boot loops on Snapdragon X Elite laptops (especially Surface Laptop 7) after installing a custom kernel, and how to diagnose them. Collect: (1) community reports (launchpad ubuntu-concept bug 2084951 comments about "boot loop" and removing clk_ignore_unused/pd_ignore_unused; linux-surface/linux-surface issue 1590 reports (perchbirdd May 2026 boot loop with concept image after kernel/firmware/iptsd install; anything Sept 2026); Ubuntu discourse "ubuntu-concept-snapdragon-x-elite" thread reports of reboot after logo); (2) plausible technical causes on X1E: efi runtime services (efi=noruntime), qcom watchdog (qcom-wdt / pm8xxx pon) resetting when not fed, remoteproc ADSP/CDSP firmware crash loops, PCIe/NVMe PHY power (clk_ignore_unused semantics), dracut initramfs missing modules (nvme, phy-qcom-qmp-pcie, pcie-qcom, ufs), plymouth/GPU (msm) crash, wrong DTB selected by stubble/dtbauto, kernel panic with panic= timeouts; (3) diagnosis without persistent storage: boot without quiet/splash with loglevel=7 and ignore_loglevel, systemd.log_level=debug, disabling plymouth, using pstore (efi_pstore needs EFI runtime; ramoops needs DT reserved-memory - is there one on x1e80100?), netconsole over USB ethernet, journald Storage=persistent then reading journalctl -b -1 from a live system; (4) the "known good" kernel cmdline for the SL7 in 2026 from the community (ELLX users, horizontblau, orvitpng nix1e config, Ubuntu x1e ISO).' },
  { key: 'iptsd', prompt: 'TOPIC: the Surface Laptop 7 haptic trackpad under Linux in 2026 - it has no mechanical button, the click is force-sensed and the haptic feedback is generated by the controller. Verify: (1) linux-surface/iptsd upstream state (releases 2025/2026, did SL7/X1E support or haptic click land?); (2) alex-lentz/iptsd fork (github.com/alex-lentz/iptsd): what exactly it adds (physical/force click -> BTN_LEFT, haptics?), README, build instructions, meson deps; (3) orvitpng/nix1e iptsd changes (they said they patched iptsd to work better and that the other fork "missed the obvious solution") - find their iptsd fork/patch (github.com/orvitpng) and what it does; (4) the three touchpad modes described in linux-surface#1590 (generic HID mouse, HID multitouch that sends nothing, IPTS-like heatmaps) and how iptsd switches the controller into vendor mode; (5) the SIGILL/BTI crash of the ELLX prebuilt iptsd (branch-protection mismatch) and how to build correctly; (6) build dependencies on Fedora 44 (meson, ninja, gcc-c++, cli11-devel, eigen3-devel, fmt-devel, spdlog-devel, inih-devel, gsl-devel, hidrd?, libinput?) and any existing Fedora/COPR iptsd package; (7) udev rules / systemd units needed (iptsd@.service template, 50-iptsd.rules, LIBINPUT_IGNORE_DEVICE for the raw node but keep the Mouse node), calibration file 91-calibration-045E-0C77.conf and iptsd-calibrate usage.' },
  { key: 'community', prompt: 'TOPIC: newest Surface Laptop 7 Linux community state, Aug 6 - ' + today + '. Fetch: (1) github.com/bryce-hoehn/linux-surface-laptop-7 issues and PRs (open and closed, newest first) and any new branches/forks; (2) linux-surface/linux-surface issue 1590 comments after 2026-09-12 (use the GitHub API https://api.github.com/repos/linux-surface/linux-surface/issues/1590/comments?since=2026-09-12T00:00:00Z); (3) ProgrammerIn-wonderland/ELLX-Kernel repo activity and public.hgci.org/software/ELLX/ listing changes; (4) any new SL7 kernel trees or rebases to 7.2/7.3 (search GitHub for "romulus13" "surface laptop 7" kernel 2026), Ubuntu concept PPA linux-qcom-x1e newest version, upstream spi-hid series status (v5? merged for 7.4?), Qualcomm GENI QSPI driver status; (5) anything about Fedora or NixOS or Arch images for the SL7 (orvitpng/nix1e updates, scuggo/x1e-nixos, aarch64-laptops).' },
]

phase('Recherche')
const results = (await parallel(TOPICS.map(t => () => agent(preamble + '\n\n' + t.prompt, { label: 'recherche:' + t.key, phase: 'Recherche', schema: FINDINGS })))).filter(Boolean)
log('Recherche fertig: ' + results.length + '/' + TOPICS.length)

phase('Plan')
const plan = await agent(
  'You are the lead engineer. Today is ' + today + '. Read the local facts file "' + facts + '" completely with the Read tool (authoritative). Below is a research corpus (JSON). Write a German Markdown document "' + outDir + '\\Fedora-Plan.md" with the Write tool: ' +
  '1) Stand der Community und was sich seit August geaendert hat; 2) Wie Fedora auf dem X1E bootet (DTB-Mechanik, Secure Boot, Kernel-Stand) und was das fuer unser ISO bedeutet; 3) Boot-Loop-Analyse: die wahrscheinlichsten Ursachen fuer den Ubuntu-Boot-Loop, geordnet, und welche Absicherungen das neue ISO deshalb bekommt (GRUB-Menue mit Alternativen, Diagnose-Eintrag, konservativer Patch-Satz); 4) Entscheidung Kernel-Basis und Paketierung (binrpm-pkg cross vs. Fedora-SRPM vs. UKI mit dtbauto) mit Begruendung; 5) Entscheidung Trackpad: welcher iptsd-Fork, wie gebaut, welche Units/Regeln/Kalibrierung; 6) Konkreter Bauplan fuer das ISO Schritt fuer Schritt (Remaster-Ablauf, was in das Live-Image kommt, wie Anaconda alles in die Installation uebernimmt, Tests in QEMU vorher); 7) Risiken und offene Punkte; 8) Quellen mit Datum. Be precise; mark single-source or contradicted claims "(unverifiziert)". Return a 10-line German summary.\n\nCORPUS:\n' + JSON.stringify(results, null, 1),
  { label: 'plan', phase: 'Plan' })

return { topics: results.map(r => ({ topic: r.topic, n: r.facts.length })), plan }
