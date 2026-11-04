# iOS label text measurement cache

`-[TiUILabel sizeForFont:]` keeps the last measured attributed string and its size. This fork-specific note records why, and how far the change has been validated.

## Problem

Auto-sized layout asks each label for its content width many times per pass, because `TiViewProxy` recurses through nested `Ti.UI.SIZE` parents. Every request called `-[NSAttributedString size]`, which runs CoreText text measurement. In a Time Profiler trace of an inspection form in FireCloud (SDK 13.4.0, iPad7,5), `sizeForFont:` was 43.5% of main-thread samples, and 23.8% in a dashboard trace.

`-[NSAttributedString size]` takes no width, so the repeated calls for an unchanged label return the same result.

## Implementation and invalidation

The method compares `[label attributedText]` with the stored copy and re-measures only when they differ, by pointer first and then `isEqual:`.

- **Text and style:** text, font, colour, alignment, attributed strings and HTML all reach the comparison through `attributedText`. A style change that does not affect size just causes one extra measurement.
- **Width:** not part of the cached value. The method's width argument never affected `-[NSAttributedString size]`. `sizeThatFits:`, which does depend on width, is still called every time.
- **Line count and font scaling:** `numberOfLines`, `minimumFontSize` and `adjustsFontSizeToFitWidth` do not affect an unconstrained `size`, before or after this change.
- **Shadow and padding:** read live, outside the cache.

## Compatibility

There is no public API or behaviour change intended. Each label retains one attributed string until it is next measured or deallocated, including any HTML attachments it holds. A false cache hit would need an attribute object mutated in place. The SDK does not do this: paragraph styles are created fresh, `ATTRIBUTE_ATTACHMENT` is unsupported, and each `html` assignment creates new objects.

Upstream `tidev/titanium-sdk` does not have this change, so it needs carrying when syncing with upstream.

## Validation

On this baseline (14.0.0, `master` at `b0027631bb`):

- **Regression tests:** `tests/Resources/ti.ui.label.test.js`, `auto-size measurement`. A reused label must match a new label after each text, font, style, attributed-text, HTML and available-width change. Both pass on iOS 26.2 and 18.1 simulators, with and without the patch.
- **Broken-cache check:** with invalidation deliberately removed, the text and style test fails (`empty text: label measured 110x16, new label measured 0x16`).
- **Self-check build (not committed):** compared the cached size with a fresh `-[NSAttributedString size]` on every call. 0 mismatches in 607,200 comparisons on iPad7,5 with the synthetic benchmark below, and 0 mismatches over the regression tests in the simulator.
- **Full integration suite on an iOS 26.2 simulator:** noisy on both sides, so it can only rule out broad regressions.
  - The unmodified SDK crashed in one run (signal 11) and had 62 failures in another.
  - The patched SDK had 24 and 61 failures. The label suite ran only in the 61-failure run, so the other patched run gives it no coverage.
  - Comparing the 61-failure and 62-failure runs, 2 of 59 distinct failures are unique to the patch. `Titanium.UI.Label .textid` also fails without the patch in focused runs, and `TableView contentOffset` passed in the other patched run.
  - `Label border (without width/height)` fails with and without the patch.

## Benchmarks

Device: iPad7,5 (A10), iPadOS 17.7.11. `ti build -T device -D test`, so `iphone/Classes` used the Xcode Debug configuration. Builds alternated with a fresh process per sample and swapped order each cycle. Values are median (range), in ms.

Stall figures come from late ticks of a 16 ms JS timer. They show responsiveness, not CPU cost. Elapsed figures are time between two points in the app. Do not compare the two tables: they measure different SDK versions and workloads.

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

Map loading is not attributed to the patch: label measurement is 0.1% of its samples, the ranges overlap, and baseline medians moved by about 900 ms between sessions. A self-check build on 13.4.0 found 0 mismatches in 235,500 comparisons.

## Outstanding

- FireCloud has not been measured on 14.0.0. Its build fails there in the Hyperloop 8.0.1 generator (`unknown encoding [MapView]`).
- No Ad Hoc or App Store build has been measured, and no other device.
- No visual screenshot comparison. Dynamic type and `textStyle` fonts were checked by code reading only.
- Full integration suite has not had a clean run on either side.
