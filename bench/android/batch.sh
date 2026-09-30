#!/system/bin/sh
D=/data/local/tmp/litert
for C in $(cat $D/all_cases.txt); do $D/runcase.sh gemma-4-E2B-it.litertlm gpu $C $D/out/e2b_gpu; done
for C in $(cat $D/e4b_cases.txt); do $D/runcase.sh gemma-4-E4B-it.litertlm cpu $C $D/out/e4b_cpu; done
echo done > $D/out/BATCH_DONE
