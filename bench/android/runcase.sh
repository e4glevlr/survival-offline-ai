#!/system/bin/sh
# usage: runcase.sh <model file> <backend> <case id> <out dir>
D=/data/local/tmp/litert
M=$1; BE=$2; C=$3; OUT=$4
mkdir -p $OUT
LD_LIBRARY_PATH=$D $D/litert_lm_main --backend=$BE --model_path=$D/$M --input_prompt_file=$D/prompts/$C.txt > $OUT/$C.log 2>&1 &
PID=$!
MINAVAIL=99999999; HWM=0
while kill -0 $PID 2>/dev/null; do
  A=$(grep MemAvailable /proc/meminfo | tr -s ' ' | cut -d' ' -f2)
  [ "$A" -lt "$MINAVAIL" ] && MINAVAIL=$A
  H=$(grep VmHWM /proc/$PID/status 2>/dev/null | tr -s ' ' | cut -d' ' -f2)
  [ -n "$H" ] && [ "$H" -gt "$HWM" ] && HWM=$H
  sleep 0.5
done
wait $PID; RC=$?
T=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
echo "RESQ_META rc=$RC min_avail_kb=$MINAVAIL vmhwm_kb=$HWM batt_temp_decic=$T" >> $OUT/$C.log
