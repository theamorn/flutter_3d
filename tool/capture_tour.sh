#!/bin/zsh
# Usage: tool/capture_tour.sh <out_dir>
set -e
out=${1:-/tmp/hotel_tour}; mkdir -p $out
fvm flutter run --enable-flutter-gpu -d "iPhone 17 Pro" \
  --dart-define=HOTEL_TOUR=true --dart-define=HOTEL_PRESET=${PRESET:-high} \
  --pid-file /tmp/hotel.pid > $out/run.log 2>&1 &
until grep -q "hotel tour" $out/run.log 2>/dev/null; do sleep 1; done
seen=0
for i in 1 2 3 4 5 6 7 8; do
  until [ $(grep -c "hotel tour" $out/run.log) -gt $seen ]; do sleep 0.5; done
  seen=$(grep -c "hotel tour" $out/run.log)
  name=$(grep "hotel tour" $out/run.log | tail -1 | sed 's/.*hotel tour: //; s/ /_/g')
  sleep 5
  xcrun simctl io booted screenshot "$out/$i-$name.png"
done
kill $(cat /tmp/hotel.pid)
