# iOS label text measurement cache

`-[TiUILabel sizeForFont:]` keeps the last measured attributed string and its size. This fork-specific note records why, and how far the change has been validated.

## Problem

Auto-sized layout asks each label for its content width many times per pass, because `TiViewProxy` recurses through nested `Ti.UI.SIZE` parents. Every request called `-[NSAttributedString size]`, which runs CoreText text measurement. In one Time Profiler trace per workload in FireCloud (SDK 13.4.0, iPad7,5), `sizeForFont:` was 43.5% of main-thread samples opening an inspection form, and 23.8% opening a dashboard.

`-[NSAttributedString size]` takes no width, so repeated calls for an unchanged attributed string returned the same result in every comparison recorded here.

## Implementation and invalidation

The method compares `[label attributedText]` with the stored copy and re-measures only when they differ, by pointer first and then `isEqual:`.

- **Text and style:** text, font, colour, alignment, attributed strings and HTML all reach the comparison through `attributedText`. A style change that does not affect size just causes one extra measurement.
- **Width:** not part of the cached value. The method's width argument never affected `-[NSAttributedString size]`. `sizeThatFits:`, which does depend on width, is still called every time.
- **Line count and font scaling:** `numberOfLines`, `minimumFontSize` and `adjustsFontSizeToFitWidth` do not affect an unconstrained `size`, before or after this change.
- **Shadow and padding:** read live, outside the cache.
- **Threading:** the cache is not synchronized, so it relies on layout running on the main thread. On iOS, Kroll JS and the layout queue both run on the main run loop. No supported off-main path was found in the code that was traced, and the self-checks counted none, but nothing enforces this at runtime. See [R2](./reviews/ios-label-cache-review.md#r2-thread-safety-and-manual-memory-management).
- **Dynamic Type:** a `textStyle` font is resolved when it is assigned, and labels do not follow later category changes on their own, with or without this change. Assigning the font again picks up the new category, which changes `attributedText` and so re-measures.

## Compatibility

There is no public API or behaviour change intended. Each label retains one attributed string until it is next measured or deallocated, including any HTML attachments it holds. A false cache hit needs a size change that `isEqual:` cannot see. One way is an attribute object mutated in place, which the SDK does not appear to do: paragraph styles are created fresh, `ATTRIBUTE_ATTACHMENT` is unsupported, and each `html` assignment creates new objects. The other is process-wide font state, which the comparison does not cover directly. On iOS 26.2 and 18.1 simulators, layout matched the unmodified build after runtime font registration, Bold Text, Dynamic Type and an in-process language write. Registration and the language write changed no existing measurement, so they did not challenge the cache. With Bold Text, `UILabel` replaced `attributedText` where its fonts changed, so the next layout measured again. In both builds, existing labels keep their old bounds until the next layout after Bold Text, and until the font is assigned again after Dynamic Type. This does not prove the same for every font or device. See [R1](./reviews/ios-label-cache-review.md#r1-cache-invalidation-and-external-font-state).

Upstream `tidev/titanium-sdk` does not have this change, so it needs carrying when syncing with upstream.

## Validation

On this baseline (14.0.0, `master` at `b0027631bb`). Nothing in this section ran on 13.4.

### Visual and geometry comparison

A synthetic app rendered labels through 219 steps and saved each view as a PNG, along with its rect and size. The app and its comparison script are not in this repository. It covered:

- multiline wrapping, truncation, RTL, CJK and emoji
- padding, including vertical alignment, shadows and borders
- attributed text and HTML
- 27 updates after initial layout, applied to three label configurations
- nested auto-size containers, ListView and TableView

Off-screen labels were saved individually, because a window capture is clipped to the screen.

| Comparison | Environment | Images | Geometry differences | Pixel differences |
|---|---|---:|---:|---:|
| Unmodified vs unmodified | iOS 26.2 simulator | 407 | 0 | 0 |
| Unmodified vs patched, 2 pairs | iOS 26.2 simulator | 407 | 0 | 0 |
| Unmodified vs patched | iOS 18.1 simulator | 407 | 0 | 0 |
| Unmodified vs patched, 2 pairs (no Dynamic Type steps) | iPad7,5, iPadOS 17.7.11 | 320 | 0 | 0 |
| Unmodified vs cache that never invalidates | iOS 26.2 simulator | 407 | 40 | 65 |
| Unmodified vs cache that compares only the string | iOS 26.2 simulator | 407 | 10 | 14 |

The last two rows are deliberately broken builds. They show the comparison can detect stale measurements.

On iOS 18.1, 398 of the 407 images are byte-identical to iOS 26.2, so that row adds little rendering variety.

A reused label and a new label with the same properties differ in 11 of 87 comparisons on the simulators and 11 of 81 on the iPad. The list is the same with and without the patch on the arms compared (for example, after a shadow is added), so these differences are not caused by the cache.

The simulator apps ran at 320 points wide, in a compatibility window, because the test app has no launch storyboard. A real 14.0.0 application was not compared.

### Dynamic Type and `textStyle` fonts

On the simulators, `simctl ui content_size` changed the category while the app ran, across 6 changes from `extra-small` to `accessibility-extra-extra-extra-large`, after labels had populated measurements. Each change covered body, headline, large title, caption, scaled custom family, padded and narrow labels.

- Patched and unmodified builds matched at every step, as in the table above.
- After the font was assigned again, reused labels matched new labels in both geometry and pixels.
- Labels with no new font keep their previous font in both builds.
- This needs host control, so the regression tests cover `textStyle` changes but not category changes. The iPad run did not cover category changes either.

### Regression tests

`tests/Resources/ti.ui.label.test.js`, `auto-size measurement`, has five tests. A reused label must match a new label after each text, font, `textStyle`, style, attributed-text, HTML, padding and width change.

These tests check rendering behaviour, so they pass with or without the cache. They poll until the reused and new labels agree on two reads in a row, with a 3 second limit, because `postlayout` does not fire when a size stays the same.

`tests/native/ios/LabelMeasurementTests.m` checks the optimization itself. It counts `-[NSAttributedString size]` calls around `sizeForFont:`, so it fails if a sync drops the cache or weakens invalidation. Run it with `tests/native/ios/run.sh`, which needs XcodeGen. No CI workflow runs it.

| Build | Label suite, iOS 26.2 simulator, `en-US` |
|---|---|
| Unmodified | 30 passed, 0 failed |
| Patched | 30 passed, 0 failed |
| Cache that never invalidates | 4 failed, all in `auto-size measurement` |
| Cache that compares only the string | 3 failed, all in `auto-size measurement` |

The unmodified and patched results are the same on an iOS 18.1 simulator. These tests have not run on an iPad.

Limits of these tests:

- `tracks available width changes` passes on both broken builds, because width is not an input to the cache. It guards wrapping behaviour.
- `contentWidthForWidth:` returns the larger of `sizeThatFits:` and the cached width, so a stale size that is too small may not show. The self-check below covers that case.
- Each test stops at its first failing step.

### Self-check

An uncommitted build compared the cached size with a fresh `-[NSAttributedString size]` on every call:

- 0 mismatches and 0 calls off the main thread in 8,503 calls with the visual app on the iOS 26.2 simulator, including Dynamic Type
- the same in 510 calls with the label suite on that simulator
- 0 mismatches in 607,200 comparisons on iPad7,5 with the synthetic benchmark below, using an earlier self-check on the same baseline that did not count off-main calls

### Failures first seen only in a patched run

Neither is caused by this change.

- **`Titanium.UI.Label .textid is a String`:** depends on the device language. Under `en-UA`, a default on the test machine, iOS picks the fixture's `en-GB` strings. It fails on both builds under `en-UA` and passes on both under `en-US`. It looked unique to the patch only because the unmodified run compared against stopped its label suite early.
- **`Titanium.UI.TableView contentOffset`:** an intermittent failure that also affects the unmodified SDK. In a focused file on an iOS 26.2 simulator, it failed 3 of 3 runs on each build. Counting 25 added repeats per run, 61 of 78 failed unmodified and 62 of 78 failed patched. The self-check build logged no `sizeForFont:` calls during this test. The read value was short of the requested 150 by 62 on this simulator and by 68 on the iPhone Air simulator, which suggests a safe-area adjustment. That root cause has not been traced.

### Integration suite

There has been no clean run on either build, so this can only rule out regressions in what ran. All of these ran on an iOS 26.2 simulator under `en-US`.

- **UI test files, without Clipboard and SplitWindow, 3 runs per build:**
  - Excluded because a late Clipboard error and a failing SplitWindow hook can end a run early.
  - Patched: all 3 runs completed, with 39, 40 and 39 failures.
  - Unmodified: 2 runs completed, with 40 and 39 failures. The third crashed in `-[TiViewController viewDidDisappear:]` (signal 11).
  - Every failure in the completed runs occurs on both builds. 30 of them are `pixelmatch is not a function`, so snapshot tests give no signal.
  - `TableView contentOffset` failed in one run per build.
- **All test files, 3 runs per build:** 5 of 6 runs ended before the label suite, and none of the unmodified runs reached it, so these say little about labels. They had 24 to 26 failures, plus 57 in the one patched run that went further.
- **GitHub:** the `Build` workflow compiles and packages the SDK but does not run this suite. `tests-ios.yml` runs it only after a review approval. Results for a given PR are on that PR.

The repo's `build/lib/test/test.js` runs `killall Simulator`, which can disrupt other simulator work on a shared machine. The comparisons above used a separate runner on dedicated simulators.

## Benchmarks

Device: iPad7,5 (A10), iPadOS 17.7.11. `ti build -T device -D test`, so `iphone/Classes` used the Xcode Debug configuration. Builds alternated with a fresh process per sample and swapped order each cycle. Values are median (range), in ms.

Stall figures come from late ticks of a 16 ms JS timer, counting only gaps over 40 ms. They show responsiveness, not CPU cost, and the cutoff affects percentages when stalls are short. In the 14.0.0 label-change row, 101 of 125 patched samples are at or below 60 ms and 12 are 0, while no unmodified sample is at or below 60 ms. Treat -73.5% as approximate. Elapsed figures are time between two points in the app. Do not compare the two tables: they measure different SDK versions and workloads.

### 14.0.0 (`b0027631bb`): synthetic app only

40 rows of nested auto-sized labels. Not a real application. Build samples exclude the first iteration in each process.

| Metric | Type | n | Unmodified | Patched | Change |
|---|---|---:|---:|---:|---:|
| Rows added to last row laid out | Elapsed | 20 | 462 (407-508) | 239 (202-300) | -48.3% |
| Stalled time while building | Timer | 20 | 463 (407-509) | 239.5 (202-301) | -48.3% |
| Stalled time after changing one label | Timer | 125 | 185 (139-252) | 49 (0-135) | -73.5% |

### 13.4.0 (the SDK FireCloud ships with): FireCloud

Stock `13_4_0_GA` against the same SDK plus an earlier form of this patch, which used `isEqualToAttributedString:` in place of `isEqual:`. Backend and sync disabled, large local dataset. These results were not measured on 14.0.0.

| Metric | Type | n | Unmodified | Patched | Change |
|---|---|---:|---:|---:|---:|
| Dashboard settled | Timer | 5 | 3,315 (2,982-3,725) | 1,505 (1,423-1,644) | -54.6% |
| Stalled time after dashboard opens | Timer | 5 | 3,147 (2,846-3,587) | 1,423 (1,298-1,504) | -54.8% |
| Banner relayout, longest freeze | Timer | 50 | 365.5 (213-413) | 171.5 (99-219) | -53.1% |
| Form first open, stalled | Timer | 5 | 1,373 (1,356-1,522) | 964 (924-1,168) | -29.8% |
| Form later opens, stalled | Timer | 20 | 1,202.5 (1,065-1,421) | 765.5 (714-822) | -36.3% |
| Form later opens, ready | Elapsed | 20 | 755 (688-854) | 655 (604-679) | -13.2% |
| Inspections, first fetch | Elapsed | 5 | 13,071 (12,299-13,771) | 13,139 (11,682-13,512) | no change |
| Map open to ready | Elapsed | 5 | 11,709 (11,000-15,958) | 10,995 (10,527-11,210) | not attributed |

Map loading is not attributed to the patch: label measurement is 0.1% of its samples, the ranges overlap, and baseline medians moved by about 950 ms between sessions. A self-check build on 13.4.0 found 0 mismatches in 235,500 comparisons.

## Outstanding

- **13.4 backport:** FireCloud currently builds with 13.4.0, and this branch targets 14.0.0, so FireCloud does not get this optimization from it. Using it there needs a separate backport and its own validation.
- FireCloud has not been measured on 14.0.0. Its build fails there in the Hyperloop 8.0.1 generator (`unknown encoding [MapView]`), which is a separate compatibility issue.
- No Ad Hoc or App Store build has been measured, and benchmarks ran on only one device.
- The full suite has no clean run on either build.
- Mac Catalyst and physical devices were not exercised for external font state, and memory was only probed in a simulator without an app. The [review record](./reviews/ios-label-cache-review.md) lists what these checks covered.
