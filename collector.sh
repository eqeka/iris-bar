#!/usr/bin/env bash
# Streams one merged JSON line per tick to stdout for the bar to read.
# See config.sh for hardware overrides - anything left unset there is
# auto-detected below with sane fallbacks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

CACHE_DIR=~/.cache/quickshell-iris-bar
mkdir -p "$CACHE_DIR"
CPU_NET_CACHE="$CACHE_DIR/cpu_net.json"
FAST_CACHE="$CACHE_DIR/fast.json"
months_ru=(Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь)
days_ru=(Воскресенье Понедельник Вторник Среда Четверг Пятница Суббота)

# --- auto-detection (only runs for whatever config.sh left empty) ---------

if [ -z "$NET_IFACE" ]; then
  NET_IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
  [ -z "$NET_IFACE" ] && NET_IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '$2!="lo"{print $2; exit}')
fi

if [ -z "$BACKLIGHT_DEVICE" ]; then
  BACKLIGHT_DEVICE=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
fi

if [ -z "$CPU_TEMP_LABEL" ]; then
  for candidate in "CPU Temperature" "Tctl" "Tdie" "Package id 0"; do
    sensors 2>/dev/null | grep -q "^${candidate}:" && { CPU_TEMP_LABEL="$candidate"; break; }
  done
fi

if [ -z "$GPU_TEMP_LABEL" ]; then
  for candidate in "GPU Temperature" "edge" "junction"; do
    sensors 2>/dev/null | grep -q "^${candidate}:" && { GPU_TEMP_LABEL="$candidate"; break; }
  done
fi

if [ -z "$GPU_MODE" ]; then
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    GPU_MODE="nvidia"
  elif find /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1 | grep -q .; then
    GPU_MODE="amdgpu"
    AMDGPU_BUSY_FILE=$(find /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
  else
    GPU_MODE="none"
  fi
elif [ "$GPU_MODE" = "amdgpu" ]; then
  AMDGPU_BUSY_FILE=$(find /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
fi

read_cpu_temp() {
  [ -z "$CPU_TEMP_LABEL" ] && { echo 0; return; }
  sensors 2>/dev/null | awk -F: -v l="$CPU_TEMP_LABEL" '$1==l{gsub("[^0-9.]","",$2); print $2; exit}'
}
read_gpu_temp() {
  [ -z "$GPU_TEMP_LABEL" ] && { echo 0; return; }
  sensors 2>/dev/null | awk -F: -v l="$GPU_TEMP_LABEL" '$1==l{gsub("[^0-9.]","",$2); print $2; exit}'
}
read_gpu_pct() {
  case "$GPU_MODE" in
    nvidia) nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null ;;
    amdgpu) [ -n "$AMDGPU_BUSY_FILE" ] && cat "$AMDGPU_BUSY_FILE" 2>/dev/null ;;
    *) echo "" ;;
  esac
}

cpu_net_loop() {
  while true; do
    local u1 n1 s1 i1 w1 u2 n2 s2 i2 w2 rx1 tx1 rx2 tx2 net_kbps cpu_pct net_bar
    read -r _ u1 n1 s1 i1 w1 _ < <(grep '^cpu ' /proc/stat)
    rx1=$(cat "/sys/class/net/$NET_IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx1=$(cat "/sys/class/net/$NET_IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)
    sleep 1
    read -r _ u2 n2 s2 i2 w2 _ < <(grep '^cpu ' /proc/stat)
    rx2=$(cat "/sys/class/net/$NET_IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx2=$(cat "/sys/class/net/$NET_IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)

    cpu_pct=$(awk -v u1=$u1 -v n1=$n1 -v s1=$s1 -v i1=$i1 -v w1=$w1 -v u2=$u2 -v n2=$n2 -v s2=$s2 -v i2=$i2 -v w2=$w2 '
      BEGIN{t1=u1+n1+s1+i1+w1; t2=u2+n2+s2+i2+w2; dt=t2-t1; di=i2-i1; if(dt<=0) print "0.0"; else printf "%.1f", (dt-di)/dt*100}')
    net_kbps=$(awk -v r1=$rx1 -v r2=$rx2 -v t1=$tx1 -v t2=$tx2 'BEGIN{printf "%.0f", (r2-r1+t2-t1)/1024}')
    net_bar=$(awk -v n=$net_kbps 'BEGIN{v=n/20; if(v>100) v=100; printf "%.1f", v}')

    printf '{"cpu_pct":%s,"cpu_label":"CPU %s%%","net_bar":%s,"net_label":"NET %sK"}\n' \
      "$cpu_pct" "${cpu_pct%.*}" "$net_bar" "$net_kbps" > "$CPU_NET_CACHE.tmp"
    mv "$CPU_NET_CACHE.tmp" "$CPU_NET_CACHE"
  done
}

fast_stats_loop() {
  while true; do
    local cpu_temp gpu_temp gpu_pct ram_pct swap_pct disk_pct bright_pct gpu_label

    cpu_temp=$(read_cpu_temp); [ -z "$cpu_temp" ] && cpu_temp=0
    gpu_temp=$(read_gpu_temp); [ -z "$gpu_temp" ] && gpu_temp=0
    gpu_pct=$(read_gpu_pct)
    if [ -z "$gpu_pct" ]; then gpu_pct=0; gpu_label="GPU N/A"; else gpu_label="GPU ${gpu_pct}%"; fi

    ram_pct=$(free -b | awk '/^Mem:/{printf "%.1f", $3/$2*100}')
    swap_pct=$(free -b | awk '/^Swap:/{if($2==0) print "0.0"; else printf "%.1f", $3/$2*100}')
    disk_pct=$(df / | awk 'NR==2{gsub("%","",$5); print $5}')

    if [ -n "$BACKLIGHT_DEVICE" ]; then
      bright_pct=$(brightnessctl --device="$BACKLIGHT_DEVICE" -m 2>/dev/null | cut -d, -f4 | tr -d '%')
    fi
    [ -z "$bright_pct" ] && bright_pct=0

    local vol_raw mic_raw vol_pct mic_pct vmuted mmuted vol_label mic_label layout_full layout
    vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    mic_raw=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
    vol_pct=$(awk '{printf "%.0f", $2*100}' <<< "$vol_raw")
    mic_pct=$(awk '{printf "%.0f", $2*100}' <<< "$mic_raw")
    vmuted=""; mmuted=""
    grep -q MUTED <<< "$vol_raw" && vmuted=" muted"
    grep -q MUTED <<< "$mic_raw" && mmuted=" muted"
    vol_label="VOL ${vol_pct}%${vmuted}"
    mic_label="MIC ${mic_pct}%${mmuted}"
    layout_full=$(niri msg keyboard-layouts 2>/dev/null | awk '/^ \*/{ $1=$2=""; sub(/^  */,""); print; exit }')
    case "$layout_full" in
      Russian*) layout="RU" ;;
      English*) layout="EN" ;;
      "") layout="?" ;;
      *) layout=$(echo "$layout_full" | cut -c1-2 | tr 'a-z' 'A-Z') ;;
    esac

    printf '{"cpu_temp_pct":%s,"cpu_temp_label":"CPU %s°","gpu_pct":%s,"gpu_label":"%s","gpu_temp_pct":%s,"gpu_temp_label":"GPU %s°","ram_pct":%s,"ram_label":"RAM %s%%","swap_pct":%s,"swap_label":"SWAP %s%%","disk_pct":%s,"disk_label":"DISK %s%%","bright_pct":%s,"bright_label":"BRI %s%%","vol_pct":%s,"vol_label":"%s","mic_pct":%s,"mic_label":"%s","layout":"%s"}\n' \
      "$cpu_temp" "${cpu_temp%.*}" "$gpu_pct" "$gpu_label" "$gpu_temp" "${gpu_temp%.*}" \
      "$ram_pct" "${ram_pct%.*}" "$swap_pct" "${swap_pct%.*}" "$disk_pct" "$disk_pct" \
      "$bright_pct" "$bright_pct" \
      "$vol_pct" "$vol_label" "$mic_pct" "$mic_label" "$layout" > "$FAST_CACHE.tmp"
    mv "$FAST_CACHE.tmp" "$FAST_CACHE"
    sleep 0.3
  done
}

# seed caches so the first prints aren't empty
echo '{"cpu_pct":0,"cpu_label":"CPU 0%","net_bar":0,"net_label":"NET 0K"}' > "$CPU_NET_CACHE"
echo '{"cpu_temp_pct":0,"cpu_temp_label":"CPU 0°","gpu_pct":0,"gpu_label":"GPU N/A","gpu_temp_pct":0,"gpu_temp_label":"GPU 0°","ram_pct":0,"ram_label":"RAM 0%","swap_pct":0,"swap_label":"SWAP 0%","disk_pct":0,"disk_label":"DISK 0%","bright_pct":0,"bright_label":"BRI 0%","vol_pct":0,"vol_label":"VOL 0%","mic_pct":0,"mic_label":"MIC 0%","layout":"?"}' > "$FAST_CACHE"

cpu_net_loop &
fast_stats_loop &

while true; do
  year=$(date +%Y); month=$(date +%-m); day=$(date +%-d)
  hour=$(date +%-H); minute=$(date +%-M); second=$(date +%-S)
  day_of_year=$(date +%-j); wday=$(date +%w)
  days_in_year=$(date -d "$year-12-31" +%j)
  days_in_month=$(date -d "$year-$month-01 +1 month -1 day" +%-d)

  year_pct=$(awk -v d=$day_of_year -v t=$days_in_year 'BEGIN{printf "%.1f", d/t*100}')
  month_pct=$(awk -v d=$day -v t=$days_in_month 'BEGIN{printf "%.1f", d/t*100}')
  day_pct=$(awk -v h=$hour -v m=$minute -v s=$second 'BEGIN{printf "%.1f", (h*3600+m*60+s)/86400*100}')
  hour_pct=$(awk -v m=$minute -v s=$second 'BEGIN{printf "%.1f", (m*60+s)/3600*100}')
  minute_pct=$(awk -v s=$second 'BEGIN{printf "%.1f", s/60*100}')
  year_num="$year"
  month_num=$(printf '%02d' "$month")
  day_num=$(printf '%02d' "$day")
  hour_num=$(printf '%02d' "$hour")
  minute_num=$(printf '%02d' "$minute")
  month_name=${months_ru[$((month-1))]}
  day_name=${days_ru[$wday]}

  if [ -n "$BIRTH_DATE" ]; then
    life_days_total=$(( ( $(date -d "$BIRTH_DATE +$LIFE_EXPECTANCY_YEARS years" +%s) - $(date -d "$BIRTH_DATE" +%s) ) / 86400 ))
    life_days_lived=$(( ( $(date +%s) - $(date -d "$BIRTH_DATE" +%s) ) / 86400 ))
    life_pct=$(awk -v d=$life_days_lived -v t=$life_days_total 'BEGIN{v=d/t*100; if(v<0)v=0; if(v>100)v=100; printf "%.2f", v}')
    life_label="LIFE ${life_days_lived}/${life_days_total}"
  else
    life_pct=0
    life_label=""
  fi

  date_json=$(printf '"year_pct":%s,"month_pct":%s,"day_pct":%s,"hour_pct":%s,"minute_pct":%s,"year_num":"%s","month_num":"%s","day_num":"%s","hour_num":"%s","minute_num":"%s","month_name":"%s","day_name":"%s","life_pct":%s,"life_label":"%s"' \
    "$year_pct" "$month_pct" "$day_pct" "$hour_pct" "$minute_pct" "$year_num" "$month_num" "$day_num" "$hour_num" "$minute_num" "$month_name" "$day_name" "$life_pct" "$life_label")

  cpu_net_json=$(cat "$CPU_NET_CACHE" 2>/dev/null); cpu_net_json=${cpu_net_json#\{}; cpu_net_json=${cpu_net_json%\}}
  fast_json=$(cat "$FAST_CACHE" 2>/dev/null); fast_json=${fast_json#\{}; fast_json=${fast_json%\}}

  printf '{%s,%s,%s}\n' "$date_json" "$cpu_net_json" "$fast_json"

  sleep 0.3
done
