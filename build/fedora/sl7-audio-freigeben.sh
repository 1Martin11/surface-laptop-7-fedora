#!/bin/bash
# SL7-Projekt: kontrollierte Freigabe von ADSP/Audio (Lautsprecher ohne Hardware-Schutz!). Einmalig als root ausfuehren,
# NUR unter Kernel B (7.3.0-rc3-sl7b) oder A (7.0.0-rc4-sl7), beide mit Kernel-Lautstaerkelimit. Ablauf:
#   Audio-Sitzung des Benutzers anhalten -> ADSP laden -> Soundkarte abwarten -> Limit pruefen (PA Volume max=6) ->
#   Lautsprecher-Regler auf 0 -> Sperre entfernen (Denylist, Bootparameter der SL7-Kernel, initramfs) -> Sitzung wieder starten.
set -u
LOG=/var/lib/sl7/audio-freigabe.log; mkdir -p /var/lib/sl7; exec > >(tee -a "$LOG") 2>&1; echo "== $(date -Is) sl7-audio-freigeben"
[ "$(id -u)" = 0 ] || { echo "als root (sudo) ausfuehren"; exit 1; }
K=$(uname -r); case "$K" in 7.3.0-rc3-sl7b|7.0.0-rc4-sl7) ;; *) echo "ABBRUCH: Kernel $K hat kein Lautstaerke-Limit (nur Kernel B/A)"; exit 1;; esac
users() { loginctl list-users --no-legend 2>/dev/null | awk '{print $2}'; }
audio_session() { for u in $(users); do uid=$(id -u "$u"); sudo -u "$u" XDG_RUNTIME_DIR=/run/user/$uid systemctl --user "$1" wireplumber pipewire-pulse pipewire >/dev/null 2>&1; done; }
audio_session stop; echo "Audio-Sitzung angehalten"
modprobe qcom_q6v5_pas || { echo "ABBRUCH: qcom_q6v5_pas laedt nicht"; audio_session start; exit 1; }
for i in $(seq 1 90); do grep -q '^ *[0-9]' /proc/asound/cards 2>/dev/null && break; sleep 1; done
IDX=$(grep -E '^ *[0-9]' /proc/asound/cards | grep -iE 'x1e|romulus|surface' | head -1 | awk '{print $1}'); [ -n "$IDX" ] || IDX=$(grep -E '^ *[0-9]' /proc/asound/cards | head -1 | awk '{print $1}')
[ -n "$IDX" ] || { echo "ABBRUCH: keine Soundkarte nach 90 s (remoteproc: $(cat /sys/class/remoteproc/remoteproc*/state 2>/dev/null | tr '\n' ' '))"; audio_session start; exit 1; }
cat /proc/asound/cards; amixer -c "$IDX" contents > /var/lib/sl7/amixer-erstlauf.txt
BAD=0; while read -r line; do
  numid=$(sed -n 's/^numid=\([0-9]*\),.*/\1/p' <<<"$line"); name=$(sed -n "s/.*name='\([^']*\)'.*/\1/p" <<<"$line")
  max=$(amixer -c "$IDX" cget numid="$numid" | sed -n 's/.*,max=\([0-9]*\).*/\1/p' | head -1)
  case "$name" in
    Spkr*"PA Volume") echo "  $name: max=$max (Soll 6)"; [ "${max:-99}" -le 6 ] || BAD=1; amixer -c "$IDX" cset numid="$numid" 0 >/dev/null && echo "    -> auf 0 gesetzt";;
    "WSA WSA_RX0 Digital Volume"|"WSA WSA_RX1 Digital Volume") echo "  $name: max=$max (Soll 81)"; [ "${max:-999}" -le 81 ] || BAD=1;;
    *"PA Volume"*) amixer -c "$IDX" cset numid="$numid" 0 >/dev/null; echo "  $name: max=$max (kein Lautsprecher, auf 0 gesetzt)";;
  esac
done < <(amixer -c "$IDX" controls | grep -E "PA Volume|Digital Volume")
alsactl store 2>/dev/null
if [ "$BAD" = 1 ]; then
  echo "LIMIT NICHT WIRKSAM - Audio bleibt gesperrt. Nichts abspielen! Neustart empfohlen."
  echo 'blacklist qcom_q6v5_pas' > /etc/modprobe.d/sl7-adsp-sperre.conf; audio_session start; exit 2
fi
echo "Limit wirksam. Sperre wird entfernt (nur Kernel A/B, Fedora-Stock-Kernel bleibt ohne ADSP)."
rm -f /etc/modprobe.d/anaconda-denylist.conf /etc/modprobe.d/sl7-adsp-sperre.conf
for k in 7.3.0-rc3-sl7b 7.0.0-rc4-sl7; do [ -f /boot/vmlinuz-$k ] || continue
  grubby --update-kernel=/boot/vmlinuz-$k --remove-args="modprobe.blacklist=qcom_q6v5_pas" 2>/dev/null
  dracut -f /boot/initramfs-$k.img "$k" >/dev/null 2>&1 && echo "initramfs $k ohne Sperre neu gebaut"; done
touch /var/lib/sl7/audio-freigegeben; audio_session start
echo "FERTIG. Lautstaerke in KDE <= 70 %, niemals das Profil 'Pro Audio'. Akku-Anzeige/USB-C-Altmode sind ab jetzt aktiv."
