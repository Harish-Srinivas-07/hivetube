#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo " HiveTube: Seek Stress Integration Test Runner"
echo "============================================================"

# Check for connected devices
echo "Checking connected devices..."
flutter devices

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  echo ""
  echo "Usage: ./tool/run_seek_stress.sh [device-id]"
  echo "Example: ./tool/run_seek_stress.sh android"
  echo "Example: ./tool/run_seek_stress.sh macos"
  echo "Example: ./tool/run_seek_stress.sh emulator-5554"
  echo ""
  echo "Running on the default available device..."
  flutter test integration_test/seek_stress_test.dart
else
  echo "Running integration test on device: $DEVICE"
  flutter test -d "$DEVICE" integration_test/seek_stress_test.dart
fi

