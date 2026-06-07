#!/bin/bash
_curdir="`dirname $(readlink -f $0)`"

OUTPUT_FILE="perf_stat_`date '+%Y-%m-%d_%H-%M-%S'`.txt"
METRICS="$(grep -v '^#' $_curdir/metrics.sh | tr '\n' ',' | sed 's/,$//')"
EVENTS="$(grep -v '^#' $_curdir/events.sh | tr '\n' ',' | sed 's/,$//')"
if [ -n "$EVENTS" ]; then
    EVENTS="-e $EVENTS"
fi
if [ -n "$METRICS" ]; then
    METRICS="-M $METRICS"
fi
DUR=${DUR:-1}
CMD="ad perf perf_x86 stat -a $METRICS $EVENTS --per-socket --metric-no-group -o $OUTPUT_FILE sleep $DUR"
if [[ $DRY_RUN -eq 1 ]]; then
    echo $CMD
    exit
fi
echo 0 > /proc/sys/kernel/nmi_watchdog
echo $CMD
$CMD
echo 1 > /proc/sys/kernel/nmi_watchdog
cat $OUTPUT_FILE
ad cecho -Y "logs saved to $OUTPUT_FILE"
