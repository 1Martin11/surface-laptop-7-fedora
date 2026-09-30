#!/usr/bin/env bash
# ELLX-Tree: neuesten Tag holen, Packaging-Cross-Compile-Unterstuetzung pruefen, Doku lesen.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
cd "$K" || exit 1
echo "=== Tag 7.0.0-rc4-12 holen"
git fetch -q --depth 1 origin tag 7.0.0-rc4-12 2>&1 | tail -2
git log -1 --format='%h %cd %s' --date=short 7.0.0-rc4-12 2>/dev/null
echo "=== Version im Tag"; git show 7.0.0-rc4-12:Makefile | sed -n '2,5p'
echo "=== Diff-Stat Branch 7.0-sl7 -> Tag 7.0.0-rc4-12 (nur Dateinamen, Top 60)"
git diff --stat HEAD 7.0.0-rc4-12 2>/dev/null | tail -1
git diff --name-only HEAD 7.0.0-rc4-12 2>/dev/null | grep -vE '^(Documentation|tools|rust|samples)/' | grep -E 'debian|dts/qcom/x1e|hid|ath12k|dwc3|ov02c10|sound/soc/qcom|gpu/drm/msm|Makefile$' | head -60
echo "=== Changes.md (Kopf)"; head -40 Changes.md 2>/dev/null
echo "=== Ubuntu.md (Kopf)"; head -30 Ubuntu.md 2>/dev/null
echo "=== debian/rules.d Cross-Compile-Logik"
grep -n "CROSS_COMPILE\|DEB_HOST_ARCH\|DEB_BUILD_ARCH\|do_tools\b\|skipabi\|skipmodule\|skipdbg\|skipretpoline\|do_dtbs\|do_stubble" debian/rules.d/0-common-vars.mk debian/rules.d/2-binary-arch.mk debian/rules.d/1-maintainer.mk debian/rules 2>/dev/null | head -40
echo "=== debian/rules.d Dateien"; ls debian/rules.d
echo "=== annotations qcom-x1e (SL7-relevante Optionen)"
grep -nE "^CONFIG_(SPI_HID|HID_SPI|ATH12K|SND_SOC_QCOM|SND_SOC_WCD9385|SND_SOC_WSA88|VIDEO_OV02C10|DRM_MSM|QCOM_PMIC_GLINK|ARM64_64K_PAGES|ARM64_16K_PAGES|ARM64_4K_PAGES|HZ_|PREEMPT|LTO|ARM64_PSEUDO_NMI|ENERGY_MODEL|CPU_FREQ_DEFAULT|QCOM_Q6V5|PHY_QCOM|USB_DWC3|SURFACE|BATTERY_QCOM|UCSI|TYPEC_MUX_PS883|INPUT_TOUCHSCREEN|HID_MULTITOUCH|QCOM_BATTMGR|MSM_GEM|VIRT|MODULE_SIG|MODULE_COMPRESS|EFI_ZBOOT|INITRAMFS)" debian.qcom-x1e/config/annotations | head -60
echo "=== .config vorhanden?"; ls -la .config 2>/dev/null || echo "kein .config"
echo "=== Concept-Clone Status"
ls /work/sl7/kernel/; du -sh /work/sl7/kernel/* 2>/dev/null
