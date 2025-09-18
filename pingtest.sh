#!/bin/bash
# Run with: bash pingtest.sh
# Logs will be saved in ~/ping-logs/<hostname>_<date>.log

# Targets
ASUS=192.168.50.1
TELMEX=192.168.1.254     # replace if Telmex gateway differs
ISP_EDGE=200.38.193.226
GOOGLE=8.8.8.8
CLOUDFLARE=1.1.1.1

# Host label (so you know which Mac is which in logs)
HOSTNAME=$(hostname -s)

# Log directory
OUTDIR="./tmp"
mkdir -p "$OUTDIR"

# Log file (same name on both Macs, will contain host label in entries)
LOGFILE="$OUTDIR/pingtest_$(date +%Y%m%d_%H%M%S).log"

echo "Starting ping test on $HOSTNAME at $(date)" | tee -a "$LOGFILE"

# Function to run a ping with target and label
run_ping () {
  TARGET=$1
  LABEL=$2
  echo "=== [$HOSTNAME] $LABEL ($TARGET) === $(date)" | tee -a "$LOGFILE"
  ping -c 50 "$TARGET" | sed "s/^/[$HOSTNAME] $LABEL: /" | tee -a "$LOGFILE"
}

# Run pings sequentially (so logs are clean in one file, aligned by host)
run_ping "$ASUS" "ASUS"
run_ping "$TELMEX" "TELMEX"
run_ping "$ISP_EDGE" "ISP_EDGE"
run_ping "$GOOGLE" "GOOGLE"
run_ping "$CLOUDFLARE" "CLOUDFLARE"


echo "Completed on $HOSTNAME at $(date)" | tee -a "$LOGFILE"

# Extract round-trip data into summary file
SUMMARYFILE="$OUTDIR/roundtrip_summary.log"
grep "round-trip" "$OUTDIR"/pingtest_*.log > "$SUMMARYFILE"
echo "Round-trip summary saved to $SUMMARYFILE"
