# iOS label text measurement cache (13.4.0 backport)

Auto-sized layout asks each label for its content width many times per pass, and every request ran `-[NSAttributedString size]` through CoreText. That method takes no width, so repeated calls for an unchanged label return the same result.

`-[TiUILabel sizeForFont:]` now keeps the last measured attributed string and its size, and measures again only when `[label attributedText]` differs. `sizeThatFits:`, shadow and padding still run on every call. There is no public API change. Statements in `sizeForFont:` that had no effect on the result are removed.

This branch carries the change from `master` (`fac879d4f5`, 14.0.0) onto `13_4_0_GA`. Upstream does not have it, so it needs carrying when changing the base. Its assumptions and review are recorded on `master` in `maintainer-docs/ios-label-text-measurement.md` and `maintainer-docs/reviews/ios-label-cache-review.md`.

Differences from `master`:

- The three `padding` steps are removed from the JS tests, because `Label.padding` does not exist in 13.4.0.
- `tests/native/ios` has a label-only host and project, because the 14.0.0 harness depends on multi-scene support. Run it with `tests/native/ios/run.sh 'platform=iOS Simulator,id=<device UUID>'`. No workflow runs it.

## Validation

All of this ran on 2026-11-06 against an SDK built from this source before it was committed, compared with stock `13_4_0_GA`.

- **Native tests:** 2 of 2 passed on iOS 26.2 and 18.1 simulators. With the cache removed, or comparing only the string, 2 of 2 failed on iOS 26.2.
- **JS label suite, `en-US`:** 26 passed, 0 failed of 28 on both builds, on iOS 26.2 and 18.1 simulators. This includes all 5 `auto-size measurement` tests.
- **Visual and geometry comparison:** 407 images over 219 steps, 2 pairs on iOS 26.2 and 1 pair on iOS 18.1, with 0 geometry and 0 pixel differences. The app is not in this repository. Its `padding` steps have no effect on 13.4.0.

## Device results

iPad7,5, iPadOS 17.7.11, `ti build -T device -D test`, which uses the Xcode Debug configuration for `iphone/Classes`. One application with a large local dataset, backend and sync disabled. 5 alternating cycles, with a fresh process per sample. Median (range), in ms.

Stalled figures and longest freezes come from late ticks of a 16 ms JS timer, counting only gaps over 40 ms. They show responsiveness, not CPU cost. Ready and settled are elapsed times between two points in the app.

| Metric | n | Stock | Patched | Change |
|---|---:|---:|---:|---:|
| Dashboard settled | 5 | 3,726 (3,223-3,789) | 1,720 (1,610-1,831) | -53.8% |
| Stalled in 5 s after dashboard opens | 5 | 3,576 (3,093-3,715) | 1,534 (1,485-1,710) | -57.1% |
| Banner relayout, stalled per cycle | 50 | 765 (635-811) | 376.5 (255-417) | -50.8% |
| Form first open, stalled | 5 | 1,378 (1,321-1,460) | 915 (842-978) | -33.6% |
| Form later opens, stalled | 20 | 1,103.5 (1,015-1,336) | 626.5 (548-719) | -43.2% |
| Form later opens, ready | 20 | 635 (570-660) | 520.5 (490-561) | -18.0% |

Collection fetching did not change.

## Not validated

- No Ad Hoc or App Store build was measured, so these figures do not establish the gain in a Release configuration.
- The full integration suite did not run on 13.4.0.
- The JS tests did not run against broken caches on 13.4.0.
- The visual comparison and JS tests did not run on a device.
- Results come from one device and one application.
