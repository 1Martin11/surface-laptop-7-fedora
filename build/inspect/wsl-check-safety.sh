#!/usr/bin/env bash
# Sicherheits-/Vollstaendigkeits-Checks am ELLX-Tree: Speaker-Volume-Limit (LP #2149808), Kernel-Config-Optionen, neuere Concept-Branches.
set -uo pipefail
export LC_ALL=C
K=/work/sl7/kernel/ellx-7.0-sl7
cd "$K"
echo "=== [1] Speaker-Limit-Patch (SAUCE: ASoC: qcom: x1e80100: limit speaker volumes) im Tree?"
grep -n -i 'limit\|max_volume\|volume\|SND_SOC_DAPM\|wsa' sound/soc/qcom/x1e80100.c | head -20
echo "--- Dateigroesse/Zeilen: $(wc -l < sound/soc/qcom/x1e80100.c)"
grep -rn -i 'speaker.*limit\|limit.*speaker\|volume.*limit' sound/soc/qcom/ sound/soc/codecs/wsa884x.c 2>/dev/null | head -10
echo "--- Concept-Tree (7.0.0-22.22) zum Vergleich:"
grep -c -i 'limit' /work/sl7/kernel/concept-qcom-x1e-7.0/sound/soc/qcom/x1e80100.c
echo
echo "=== [2] Kernel-Config: SL7-relevante Optionen"
for o in I2C_HID_OF I2C_HID_CORE TYPEC_MUX_PS883X PHY_QCOM_EUSB2_REPEATER PHY_NXP_PTN3222 BATTERY_QCOM_BATTMGR UCSI_PMIC_GLINK TYPEC_UCSI SND_SOC_WSA884X SND_SOC_WCD938X SND_SOC_WCD938X_SDW SND_SOC_X1E80100 SND_SOC_QCOM_SDW SOUNDWIRE_QCOM HID_SURFACE SURFACE_AGGREGATOR SURFACE_AGGREGATOR_REGISTRY SURFACE_AGGREGATOR_BUS SURFACE_AGGREGATOR_HUB SURFACE_HID SURFACE_KBD SURFACE_PLATFORM_PROFILE SURFACE_FAN VIDEO_QCOM_CAMSS VIDEO_OV02C10 SPI_HID HID_MULTITOUCH QCOM_PD_MAPPER QCOM_PDR_HELPERS QCOM_Q6V5_PAS ATH12K DRM_MSM PHY_QCOM_QMP_PCIE PCIE_QCOM PHY_QCOM_QMP_USB PHY_QCOM_QMP_COMBO USB_DWC3 USB_DWC3_QCOM QCOM_APR SND_SOC_QDSP6 FW_LOADER_COMPRESS_ZSTD FW_LOADER_COMPRESS_XZ EFI_ZBOOT LEDS_GPIO INPUT_GPIO_KEYS BACKLIGHT_PWM PWM_QCOM_PMIC QCOM_CPUFREQ_HW ARM_QCOM_CPUFREQ_HW QCOM_GPI_DMA SPI_QCOM_GENI I2C_QCOM_GENI SERIAL_QCOM_GENI BT_QCA BT_HCIUART_QCA RTC_DRV_PM8XXX QCOM_PMIC_GLINK QCOM_RPMH QCOM_SMD_RPM QCOM_TZMEM_MODE_SHMBRIDGE QCOM_QSEECOM QCOM_QSEECOM_UEFISECAPP; do
  v=$(grep -E "^CONFIG_$o=" .config | cut -d= -f2); [ -z "$v" ] && v="-"
  printf '  %-34s %s\n' "$o" "$v"
done
echo
echo "=== [3] Concept-Launchpad: Branch resolute-x1e (Version?)"
git ls-remote https://git.launchpad.net/~ubuntu-concept/ubuntu/+source/linux/+git/resolute 2>/dev/null | grep -E 'heads/(resolute-x1e|qcom-x1e)'
mkdir -p /work/sl7/kernel/probe && cd /work/sl7/kernel/probe
rm -rf rx && git clone -q --depth 1 --single-branch -b resolute-x1e --filter=blob:none --sparse https://git.launchpad.net/~ubuntu-concept/ubuntu/+source/linux/+git/resolute rx 2>&1 | tail -1
if [ -d rx ]; then cd rx && git sparse-checkout set Makefile debian.qcom-x1e/changelog debian.master/changelog sound/soc/qcom >/dev/null 2>&1; echo "--- resolute-x1e:"; git log -1 --format='%h %cd %s' --date=short; sed -n '2,5p' Makefile | tr '\n' ' '; echo; head -3 debian.qcom-x1e/changelog 2>/dev/null; echo "--- Speaker-Limit in resolute-x1e?"; grep -n -i 'limit' sound/soc/qcom/x1e80100.c 2>/dev/null | head -5; fi
