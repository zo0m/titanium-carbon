# Maintainer Documentation

This folder contains documentation relevant to the ongoing maintenance of Titanium.

Please ensure when updating the associated area to ensure this documentation is kept up to date.

The documentation is as follows:

* [CI Setup](./ci-setup.md)
  * Describes the usage of GitHub actions for the CI setup
* [Releasing the SDK](./releasing-the-sdk.md)
  * Describes the process of creating a release
* [iOS label text measurement cache](./ios-label-text-measurement.md)
  * Records why labels cache text measurement, how it is invalidated and how it was validated
* [iOS label cache review](./reviews/ios-label-cache-review.md)
  * Records the investigation of each code review finding on that cache
* [Upstream sync, 2026-11-11](./upstream-sync-2026-11-11.md)
  * Records the merge of upstream `main` into the fork, its validation and FireCloud compatibility
* [iOS: Hyperloop loses CocoaPods classes on clean builds](./ios-hyperloop-cocoapods-clean.md)
  * Records why SDK 14 clean builds delete Hyperloop's pod frameworks, the fix and its validation
