#!/bin/bash
# Usage: tests/native/ios/run.sh 'platform=iOS Simulator,id=<device UUID>'
# Requires Xcode and XcodeGen. Builds artifacts outside the repository.
set -euo pipefail
if [[ $# != 1 ]]; then
  echo "Usage: $0 'platform=iOS Simulator,id=<device UUID>'" >&2
  exit 1
fi
export TITANIUM_SDK_ROOT
TITANIUM_SDK_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export LABEL_TEST_OUTPUT
LABEL_TEST_OUTPUT="$(mktemp -d /tmp/titanium-label-tests.XXXXXX)"
xcodegen generate --spec "$TITANIUM_SDK_ROOT/tests/native/ios/project.yml" \
  --project-root "$LABEL_TEST_OUTPUT" --project "$LABEL_TEST_OUTPUT"
xcodebuild -quiet -project "$LABEL_TEST_OUTPUT/LabelRegression.xcodeproj" \
  -scheme LabelTests -destination "$1" -derivedDataPath "$LABEL_TEST_OUTPUT/build" \
  -collect-test-diagnostics never test
