#!/usr/bin/env bash
set -euo pipefail

# Usage: ./monitor_pid.sh <PID> [interval_sec]
PID=${1:?Usage: $0 <PID> [interval_sec]}
INTERVAL=${2:-2}

# ─── Disks to monitor ─────────────────────────────
DISKS=(disk19 disk4)
# ──────────────────────────────────────────────────

# ─── Column widths ───────────────────────────────
w_ts=19     # Timestamp
w_cpu=6     # %CPU
w_time=11   # CPU Time
w_thr=7     # Threads
w_mem=7     # MemMB
w_tps=12    # per-disk TPS
w_mbps=12   # per-disk MB/s
# ──────────────────────────────────────────────────

# ─── Build printf format strings ─────────────────
header_fmt="%-${w_ts}s %${w_cpu}s %${w_time}s %${w_thr}s %${w_mem}s"
data_fmt="%-${w_ts}s %${w_cpu}.2f %${w_time}s %${w_thr}d %${w_mem}.1f"
for _ in "${DISKS[@]}"; do
  header_fmt+=" %${w_tps}s %${w_mbps}s"
  data_fmt+=" %${w_tps}.0f %${w_mbps}.2f"
done
header_fmt+="\n"
data_fmt+="\n"
# ──────────────────────────────────────────────────

# ─── Print header row ────────────────────────────
headers=( Timestamp '%CPU' 'CPU Time' Threads MemMB )
for d in "${DISKS[@]}"; do
  headers+=( "${d}_TPS" "${d}_MBps" )
done
printf "${header_fmt}" "${headers[@]}"
# ──────────────────────────────────────────────────

# ─── Monitoring loop ─────────────────────────────
while true; do
  TS=$(date '+%Y-%m-%d %H:%M:%S')

  # 1) %CPU, CPU Time, RSS(KB)
  read cpu cputime rss < <(ps -p "${PID}" -o %cpu= -o time= -o rss=)

  # 2) Thread count (integer)
  threads=$(ps -M -p "${PID}" 2>/dev/null | tail -n +2 | wc -l)

  # 3) Convert RSS → MB
  mem=$(awk "BEGIN{printf \"%.1f\", ${rss}/1024}")

  # 4) iostat → KB/t, TPS, MB/s per disk; skip KB/t, grab TPS & MB/s
  line=$(iostat -d "${DISKS[@]}" "${INTERVAL}" 2 | tail -n1)
  read -r -a io <<<"${line}"
  disk_vals=()
  for ((i=0; i<${#DISKS[@]}; i++)); do
    idx=$(( i*3 + 1 ))
    disk_vals+=( "${io[idx]}" "${io[idx+1]}" )
  done

  # 5) Print aligned data row
  printf "${data_fmt}" \
    "${TS}" "${cpu}" "${cputime}" "${threads}" "${mem}" \
    "${disk_vals[@]}"
done
# ──────────────────────────────────────────────────
