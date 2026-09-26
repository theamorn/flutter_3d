#!/bin/zsh
# Usage: tool/capture_tour.sh <out_dir>
set -e
out=${1:-/tmp/hotel_tour}; mkdir -p $out
rm -f /tmp/hotel.pid

fvm flutter run --enable-flutter-gpu -d "iPhone 17 Pro" \
  --dart-define=HOTEL_TOUR=true --dart-define=HOTEL_PRESET=${PRESET:-high} \
  --pid-file /tmp/hotel.pid > $out/run.log 2>&1 &
FLUTTER_PID=$!

cleanup() {
  if [ -f /tmp/hotel.pid ]; then
    kill $(cat /tmp/hotel.pid) 2>/dev/null || true
  fi
  kill $FLUTTER_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for app to start and hotel tour to begin..."
while ! grep -q "hotel tour" $out/run.log 2>/dev/null; do
  if ! kill -0 $FLUTTER_PID 2>/dev/null; then
    echo "flutter run exited early! Log:"
    cat $out/run.log
    exit 1
  fi
  sleep 1
done

echo "Hotel tour started! Capturing 8 stops..."
seen=0
for i in 1 2 3 4 5 6 7 8; do
  until [ $(grep -c "hotel tour" $out/run.log) -gt $seen ]; do
    if ! kill -0 $FLUTTER_PID 2>/dev/null; then
      echo "flutter run exited during tour! Log:"
      cat $out/run.log
      exit 1
    fi
    sleep 0.5
  done
  seen=$(grep -c "hotel tour" $out/run.log)
  name=$(grep "hotel tour" $out/run.log | tail -1 | sed 's/.*hotel tour: //; s/ /_/g')
  echo "Capturing stop $i: $name"
  sleep 5
  xcrun simctl io booted screenshot "$out/$i-$name.png"
  echo "Captured: $out/$i-$name.png"
done

echo "All 8 stops captured in $out"
