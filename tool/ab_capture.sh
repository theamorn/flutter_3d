#!/bin/zsh
# Usage: tool/ab_capture.sh <simulator-udid> <feature-id> <out-dir> [preset]
# Screenshots every perf-probe hold: each stop with <feature-id> off, then on.
# A debug build on the simulator runs at 4-8 fps, so auto exposure, dynamic GI
# and probe re-captures are still converging a second after a hold. Shoot late
# in the probe's 4 s sample instead.
dev=$1; id=$2; out=$3; preset=${4:-ultra}; log=$out/run.log
mkdir -p $out; rm -f $out/*.png(N)
fvm flutter run -d $dev --enable-flutter-gpu --dart-define=HOTEL_PERF=true \
  --dart-define=HOTEL_PERF_AB=$id --dart-define=HOTEL_PRESET=$preset \
  --pid-file $out/app.pid > $log 2>&1 &
seen=0; i=0
while ! grep -q 'hotel perf: done' $log 2>/dev/null; do
  n=$(grep -c 'hotel perf: hold' $log 2>/dev/null)
  if [ "$n" -gt "$seen" ]; then
    seen=$n; i=$((i+1)); sleep 3.2
    name=$(grep 'hotel perf: hold' $log | tail -1 | sed 's/.*hold //; s/[^A-Za-z0-9]\{1,\}/_/g')
    # The probe prints the hold's timing line when it moves on; if it already
    # has, this shot may show the next pose.
    [ $(grep -c 'hotel perf: .* | ui ' $log) -ge $seen ] && echo "late shot: $i-$name"
    xcrun simctl io $dev screenshot "$out/$(printf %02d $i)-$name.png" >/dev/null 2>&1
  fi
  sleep 0.3
done
kill $(cat $out/app.pid) 2>/dev/null
echo "captured $i screenshots in $out"
