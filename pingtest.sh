#!/bin/bash
set -euo pipefail

# Run with: bash pingtest.sh
# Logs will be saved in ~/ping-logs/<host>_<date>.log
# You can override defaults via env vars, e.g. COUNT=200 INTERVAL=1 OUTDIR=~/ping-logs bash pingtest.sh

# Targets
ASUS=192.168.50.1
TELMEX=192.168.1.254     # replace if Telmex gateway differs
ISP_EDGE=200.38.193.226
GOOGLE=8.8.8.8
CLOUDFLARE=1.1.1.1

# Host label (so you know which Mac is which in logs)
HOSTNAME=$(hostname -s)

# Log directory (override with OUTDIR env var)
OUTDIR=${OUTDIR:-"$HOME/ping-logs"}
mkdir -p "$OUTDIR"


# Consistent date for all logs
RUNDATE=$(date +%Y%m%d_%H%M%S)
# Log file (unique per host & run)
LOGFILE="$OUTDIR/${HOSTNAME}_${RUNDATE}.log"
# Per-run CSV for machine-readable summary
CSVFILE="$OUTDIR/pingtest_${RUNDATE}.csv"
# Tunables (can be overridden via env)
COUNT=${COUNT:-50}
INTERVAL=${INTERVAL:-1}

echo "Starting ping test on $HOSTNAME at $(date)" | tee -a "$LOGFILE"
# CSV header
echo "run_date,host,label,target,tx,rx,loss_pct,min_ms,avg_ms,max_ms,stddev_ms" > "$CSVFILE"

run_ping () {
  TARGET=$1
  LABEL=$2
  echo "=== [$HOSTNAME] $LABEL ($TARGET) === $(date)" | tee -a "$LOGFILE"

  # Capture raw ping output to a temp file for parsing and prefixed logging
  TMPFILE=$(mktemp)
  # macOS-compatible flags: -c COUNT, -i INTERVAL (default 1s for non-root)
  if ping -c "$COUNT" -i "$INTERVAL" "$TARGET" >"$TMPFILE" 2>&1; then
    :
  else
    echo "[$HOSTNAME] $LABEL: ping failed" | tee -a "$LOGFILE"
  fi

  # Prefix and append raw output into the run log
  sed "s/^/[$HOSTNAME] $LABEL: /" "$TMPFILE" | tee -a "$LOGFILE"

  # Parse stats (macOS: 'packets transmitted', 'packets received', 'packet loss', 'round-trip ... = min/avg/max/stddev ms')
  TX=$(grep -Eo '[0-9]+ packets transmitted' "$TMPFILE" | awk '{print $1}' || echo 0)
  RX=$(grep -Eo '[0-9]+ packets received' "$TMPFILE" | awk '{print $1}' || echo 0)
  LOSS=$(grep -Eo '[0-9.]+% packet loss' "$TMPFILE" | awk '{print $1}' | tr -d '%' || echo 100)
  RTT_LINE=$(grep -E 'round-trip|rtt' "$TMPFILE" || true)
  if [ -n "$RTT_LINE" ]; then
    # Extract the min/avg/max/stddev numbers regardless of whether the label is 'round-trip' or 'rtt'
    RTT_FIELDS=$(echo "$RTT_LINE" | awk -F' = ' '{print $2}' | awk '{print $1}' | tr '/' ' ')
    MIN=$(echo "$RTT_FIELDS" | awk '{print $1}')
    AVG=$(echo "$RTT_FIELDS" | awk '{print $2}')
    MAX=$(echo "$RTT_FIELDS" | awk '{print $3}')
    STD=$(echo "$RTT_FIELDS" | awk '{print $4}')
  else
    MIN=""; AVG=""; MAX=""; STD=""
  fi

  # Append one record to CSV
  echo "$RUNDATE,$HOSTNAME,$LABEL,$TARGET,$TX,$RX,$LOSS,$MIN,$AVG,$MAX,$STD" >> "$CSVFILE"

  rm -f "$TMPFILE"
}

# Run pings sequentially (so logs are clean in one file, aligned by host)
run_ping "$ASUS" "ASUS"
run_ping "$TELMEX" "TELMEX"
run_ping "$ISP_EDGE" "ISP_EDGE"
run_ping "$GOOGLE" "GOOGLE"
run_ping "$CLOUDFLARE" "CLOUDFLARE"


echo "Completed on $HOSTNAME at $(date)" | tee -a "$LOGFILE"

# Extract round-trip lines into a human-readable summary file (for quick glance)
SUMMARYFILE="$OUTDIR/pingtest_summary_${RUNDATE}.log"
{
  echo "Summary generated at $RUNDATE on $HOSTNAME"
  echo "Source log: $LOGFILE"
  echo "CSV: $CSVFILE"
  grep -E "(round-trip|rtt)" "$LOGFILE" || echo "No RTT lines found."
} > "$SUMMARYFILE"

echo "Round-trip summary saved to $SUMMARYFILE"
echo "CSV summary saved to $CSVFILE"
