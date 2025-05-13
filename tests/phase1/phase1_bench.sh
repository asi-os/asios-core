#!/usr/bin/env bash
set -euo pipefail

# 1) MBW: grab the “Copy:” column from the AVG line
MBW=$(mbw 64 2>/dev/null \
  | awk '/^AVG/ && /MEMCPY/ { for(i=1;i<=NF;i++) if($i=="Copy:") print $(i+1) }>

# 2) hackbench: first “Time:” value
HACK=$(hackbench -g 8 -l 10000 --threads 2>/dev/null \
  | awk '/Time:/ { print $2; exit }')

# 3) fio seqread BW (MiB/s)
FIO=$(fio --name=seqread --rw=read --bs=1m --size=1G --numjobs=1 2>/dev/null \
  | awk '/BW=/ { match($0, /BW=([0-9.]+)MiB\/s/, m); print m[1]; exit }')

# 4) stress-ng sanity
STRESS=$(stress-ng --cpu 4 --timeout 30s --metrics-brief 2>/dev/null \
  | awk '/successful run/ { print "ok"; exit }')

# emit a single JSON object
jq -n \
  --arg mbw    "$MBW" \
  --arg hack   "$HACK" \
  --arg fio    "$FIO" \
  --arg stress "$STRESS" \
  '{ mbw:($mbw|tonumber), hackbench:($hack|tonumber), fio:($fio|tonumber), stress: $stress }'
