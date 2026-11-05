# iOS label measurement cache: review reassessment

Investigation record for the review of [PR #1](https://github.com/zo0m/titanium-carbon/pull/1), started 2026-11-05 at PR head `f41411b60d`. Line references in the original claims are relative to that commit.

The findings R1-R10 below came from an automated code review that read the code without running it. **They are unverified claims, not established defects.** Each one was investigated and given its own verdict below.

Verdicts: confirmed, partially confirmed, not substantiated, rejected or deferred. "Not substantiated" means the investigation did not establish the claim. It does not prove the issue is impossible.

The design and benchmark record is [iOS label text measurement](../ios-label-text-measurement.md). This file doesn't repeat its performance figures.

## Summary

| ID | Finding | Verdict | Disposition |
|---|---|---|---|
| R1 | External font state | Partially confirmed: the doc claim was too strong; stale layout not substantiated | Doc corrected, no code change |
| R2 | Off-main race | Not substantiated as reachable | No code change, no assertion |
| R3 | Fixed relayout delays | Partially confirmed | Replaced with bounded polling |
| R4 | Loss of the optimization goes unnoticed | Partially confirmed | Native test added, not in CI |
| R5 | Equality and memory overhead | Not substantiated | Design kept |
| R6 | Broader layout memoization | Deferred: "makes this cache unnecessary" not supported | No change, possible separate spike |
| R7 | Dead work in `sizeForFont:` | Confirmed, predates this cache | Removed |
| R8 | Repeated test setup | Confirmed | Refactored |
| R9 | Transient PR status in docs | Confirmed | Removed |
| R10 | Contribution conventions | Partially confirmed | First commit's wording handled at squash; title kept |

Unless noted, runtime checks ran on dedicated iOS 26.2 and 18.1 simulators on 2026-11-05. Probes and deliberately broken builds were local and are not committed. Comparison builds were `b0027631bb` (unmodified) and the final `TiUILabel.m`, under separate SDK names, with the compiled source checked before each comparison.

## Findings

Each finding starts with the original, unverified claim.

### R1: Cache invalidation and external font state

**Original claim.** `iphone/Classes/TiUILabel.m:70`. The cache key assumes `-[NSAttributedString size]` depends only on the string and its attributes, but CoreText can also use process-wide state that `isEqual:` never sees, and nothing invalidates the cache when that state changes. A label measuring CJK or emoji text through a fallback font could stay stale after runtime font registration, a Bold Text toggle or a language change. An oversized stale width leaves an auto-width label too wide, and `MAX()` in `contentWidthForWidth:` hides a stale width that is too small. The doc's statement that a false hit "would need an attribute object mutated in place" would then be too strong.

**Evidence inspected.** `TiUILabel.m`, `WebFont.m`, `TiLocale.m`, `TiRootViewController.m` and the app font registration step in the iOS build.

**Investigation.**

- A UIKit probe with no app measured a stored string and an equal rebuilt string, before and after each state change. It used 32 font and text combinations, including CJK, kana, emoji, Arabic, Thai and private-use characters.
- A probe in SDK-built apps (unmodified and patched) used 20 labels through these steps: populate, change state, force layout, reassign, then compare with a new label. There were 6 arms on each OS.

| Trigger | Took effect? | Effect on existing labels | Unmodified vs patched layout |
|---|---|---|---|
| Runtime registration (FontAwesome, Arial Unicode) | Yes, by explicit-font control | No measurement or run font changed: registered fonts did not join fallback | Same |
| Bold Text | Yes in-process: weight and notification changed. Private setter, not Settings | `UILabel` replaced `attributedText` on 13 of 20 labels, and the next layout missed the cache 13 times | Same |
| In-process `AppleLanguages` write | Value only: new labels did not change | No measurement changed | Same |
| Language at launch (`ja`) | Yes, in a new process | Kana fallback and width differ, but a new process has no cached value | Not applicable |
| Dynamic Type | Yes | Labels keep the old font until reassigned | Same |
| No change (control) | Not applicable | Only from the arm's own edits | Same |

**Verdict: partially confirmed.** The doc's claim that a false hit "would need" in-place mutation was too absolute. Stale layout caused by the cache was not substantiated.

**Reasoning.** A cached value is only wrong if a fresh measurement of equal content differs. No trigger produced that after layout. Bold Text does make the cached and fresh sizes differ briefly, but only until the next layout, and both builds keep the old bounds until then. After Dynamic Type, existing labels stay at the old size on both builds until the font is reassigned, so that gap predates the cache. The system-language path relies on iOS relaunching the app, which was not tested.

**Disposition.** No observers or invalidation added, because no trigger needs one. Doc and code comment corrected.

**Limitations.**

- Registration and the language write changed no existing measurement, so they did not challenge the cache. They don't prove every font or language behaves this way.
- Bold Text used a private setter, not Settings.
- Labels were auto-width only, without shadow, padding or wrapping.
- No device or Mac Catalyst run.

### R2: Thread safety and manual memory management

**Original claim.** `iphone/Classes/TiUILabel.m:71`. The unsynchronized manual-retain-release cache turns any off-main `sizeForFont:` call into a possible use-after-free, and nothing enforces the main-thread assumption. `contentWidthForWidth:` is forwarded by `USE_VIEW_FOR_METHOD` with no thread guard. One thread could run `[measuredText release]` while another runs `[value isEqual:measuredText]`, or pair `measuredText` with the wrong `measuredTextSize`. The PR's count of 0 off-main calls covers only the workloads it ran. The review suggested at least an `NSAssert([NSThread isMainThread])`.

**Evidence inspected.** Callers of `sizeForFont:` and `autoWidthForSize:`, `USE_VIEW_FOR_METHOD`, `KrollContext.m`, `TiLayoutQueue.m`, `TiViewProxy.m`, and thread-related searches across `iphone/`.

**Investigation.** `sizeForFont:` has one caller. JS runs on main (`KrollContext.m` makes `isKJSThread` the main thread), the layout timer is on the main run loop, and `relayout`, `reposition`, `toImage`, `rect` and `size` marshal to main. Nothing reads `run-on-main-thread` in `iphone/` or `cli/`. Hosted counters logged 0 off-main calls in all arms.

**Verdict: not substantiated** as a reachable race. It is true that no runtime check enforces confinement, and an off-main call would be unsafe.

**Reasoning.** The method already reads `UILabel` state, so an off-main caller would violate UIKit on the unmodified build too. Strings and sizes change together in one block on one thread, and no re-entry was found. Zero counted calls is limited evidence, so the conclusion rests mainly on the code trace.

**Disposition.** No code change. An `NSAssert` adds no Release synchronization (`ENABLE_NS_ASSERTIONS = NO`) and would be the first of its kind here. The confinement assumption is stated in the code comment and the maintainer doc.

**Limitations.** `TiUIScrollableView.m:315` was not traced to its root, and some thread-related hits outside layout were judged by name. Third-party native modules were not audited.

### R3: Fixed relayout delays

**Original claim.** `tests/Resources/ti.ui.label.test.js:431` (also 435, 578, 581 and 585). The new tests wait a fixed 100 ms for relayout instead of a layout signal. On a loaded runner, a size could be read before layout finishes and the test would fail falsely. The 18-step test multiplies that chance.

**Evidence inspected.** Delays in the test file, `TiViewProxy.m` `postlayout` dispatch, `TiLayoutQueue.m` and timing conventions across `tests/Resources`.

**Investigation.** A too-early read returns old bounds, which gives a false failure. A false pass needs old bounds that happen to be correct. JS, timers and layout share the main run loop, so load alone doesn't reorder them, but layout can take several 50 ms ticks. `postlayout` doesn't fire when geometry is unchanged, so waiting for it would hang on same-size steps.

**Verdict: partially confirmed.** The waits are timing-dependent. The "loaded runner" explanation was overstated, and no flake was observed.

**Fix.** Poll every 60 ms for two agreeing reads, up to 3 s, and fail with a message naming the step and both sizes. Steps assert whether the size must change, so old bounds that match can't pass unnoticed.

**Validation.** Patched and unmodified: 30 passed and 0 failed on both OS versions. Broken builds fail at the deadline with a useful message, such as `smaller font: label measured 156x30, new label measured 116x30`.

**Limitations.** Steps that keep their size rely only on the two-read window, about 60 ms. The new tests have not run in CI or on an iPad.

### R4: Detecting loss of the optimization

**Original claim.** `tests/Resources/ti.ui.label.test.js:417`. All five tests pass on the unmodified SDK, so a later upstream sync could drop the cache with CI still green. Comparisons also pass through `ceilf`, `MAX(sizeThatFits, cached)`, `verifyWidth:` even-number rounding, a parent-width clamp and a 1 pt tolerance, so small or clamped stale sizes can pass. The review suggested a debug-only check of cached against fresh size, or a measurement counter.

**Evidence inspected.** Test seams in `tests/`, including Hyperloop availability, debug-only compilation and `tests/native/ios`.

**Investigation.** Passing on both unmodified and patched is expected from a rendering test, so these are two separate goals. Mocha can't observe a measurement count, and a timing check or `DEBUG` property would be weak or add API. `tests/native/ios` already compiles `iphone/Classes` sources.

**Verdict: partially confirmed.** Dropping the cache would keep the mocha suite green. Some masking in the claim was overstated: layout never reads the cached height, and sizes are even integers, so the 1 pt tolerance hid nothing and was removed.

**Fix.** `LabelMeasurementTests.m` swizzles `-[NSAttributedString size]` and counts calls around `sizeForFont:`. There are no production changes.

| `TiUILabel.m` variant | XCTest failures |
|---|---|
| Final (iOS 26.2 and 18.1) | 0 |
| Cache removed | 6 |
| Compares only the string | 16 |
| Never invalidates | 22 |

**Remaining masks in the JS tests.** `ceilf` and even rounding hide differences under about 2 pt. `MAX(sizeThatFits, cached)` hides a stale width that is too small. The parent clamp hides a stale width that is too large. The native test's counts catch invalidation failures these would hide.

**Limitations.**

- The test was built with `clang` and run without an app host. **`project.yml` and `run.sh` were not run**, because XcodeGen isn't installed, so the hosted `SceneTests` target with these sources is unverified.
- No workflow runs it, so a sync that drops the cache stays green in CI unless someone runs it. CI workflows were out of scope.

### R5: Equality and memory overhead

**Original claim.** `iphone/Classes/TiUILabel.m:70`. If `-attributedText` returns a new instance, or the stored `-copy` is a different instance, the pointer check never hits and each call compares text and attribute runs with `isEqual:`. Every auto-measured label also retains a second attributed string, with its HTML attachments, and the PR measured no memory. The review suggested comparing a dirty flag cleared in the content setters, which must then cover every setter.

**Evidence inspected.** `TiUILabel.m` setters, `TiUIAttributedStringProxy.m`, and the saved form profiles.

**Investigation.**

| Simulator probe, no app host | Result |
|---|---|
| `attributedText` returns the same object between calls | 1000 of 1000, all 5 string shapes |
| `-copy` returns the same object | Yes, 0 extra bytes retained |
| Forced real copy, for comparison | 144 B to 30 KB per string |
| `isEqual:` on an equal 10 KB string | 7 us, against 798 us for `size` |

Real labels in a hosted run made 5,756 calls: 4,598 pointer hits, 1,080 `isEqual:` hits and 78 misses. All `isEqual:` hits were on plain labels after an equal text reassign, because the cache keeps its older object. In one 13.4 form profile, the getter and `isEqual:` together were 0.9% of main-thread samples.

**Verdict: not substantiated.** The pointer check does hit, and the copy shares the label's string in these checks. What holds is that a replaced string stays alive until the next measurement, or until deallocation if the label stops being measured.

**Disposition.** Design kept. A dirty flag would have to cover at least 12 setters plus the public `-label` accessor, and several of those setters don't notify layout. Stale results would be silent, and it would save about 1% of samples in that profile.

**Limitations.** Timing is from a simulator, not a device. The memory check covers the copy itself, not whole-app memory. HTML strings weren't in the no-host probe, though hosted HTML labels did hit by pointer. The workloads may not match real apps.

### R6: Broader layout memoization

**Original claim.** `iphone/Classes/TiUILabel.m:70`. The cache treats a symptom in one widget while the repeated work comes from `TiViewProxy` recursion (`TiViewProxy.m:840`, `941`). Other `USE_VIEW_FOR_CONTENT_WIDTH` widgets gain nothing. The review suggested memoizing `autoWidthForSize:`/`autoHeightForSize:` per proxy and size, which it said could make this cache unnecessary.

**Evidence inspected.** `TiViewProxy.m` auto-size paths and invalidation, and aggregates from one 13.4 form profile on an iPad.

**Investigation.** With the cache, recursion and other layout work without a widget measurement remain 18.1% of main-thread samples, `TextField` 8.3% and the label hit path 7.8%. `sizeForFont:` fell about 85% relative to `TextField` samples, while recursion stayed flat.

**Verdict: deferred.** The recursion is real and untouched by this PR. The claim that a proxy cache could make this one unnecessary isn't supported.

**Reasoning.** The label cache serves every width and every sibling. A proxy cache misses on each new size and after each invalidation, and `willChangeSize` cascades through parents and children, so hook-based invalidation would clear unchanged siblings. It would need inputs from layout properties, descendants, visibility and ancestors, and several label setters don't notify. The two caches address overlapping but different repeated work.

**Disposition.** Not implemented. A separate spike is worthwhile only as its own measured work, on top of this cache. Suggested acceptance: at least 15% lower stalls on a device with non-overlapping ranges, 0 visual differences, and broken invalidation builds that fail.

**Limitations.** One trace from one app, on an earlier form of the patch. Windows differ between the traces, so the relative figure is an inference.

### R7: Dead work in `sizeForFont:`

**Original claim.** `iphone/Classes/TiUILabel.m:60`. `maxSize` is computed and adjusted but never read, the `hasSuffix:` check runs on every call, `suggestedWidth` has no effect on the result and `returnVal` only aliases `measuredTextSize`. The review suggested removing them while keeping `requiresLayout = YES`.

**Evidence inspected.** `sizeForFont:` at the PR head and at `b0027631bb`, its one caller, and conditional compilation.

**Verdict: confirmed.** `maxSize`, the `hasSuffix:` block and `returnVal` had no effect on the result. All but `returnVal` predate the cache, and there are no platform branches in the method. In one 13.4 profile, `hasSuffix:` and `text` were about 30% of the hit path, or 2.3% of main-thread samples.

**Fix.** Removed them. `suggestedWidth` stays because the caller passes it. `requiresLayout = YES` also has no reader in `iphone/`, but it stays, because removing the ivar is separate cleanup. The shadow adjustment is live and unchanged.

**Validation.** On iOS 26.2, unmodified vs final: 407 images and 219 steps, 0 geometry differences, 0 pixel differences. Label suite and native test results are under R3 and R4. No device run after this cleanup.

### R8: Repeated test setup

**Original claim.** `tests/Resources/ti.ui.label.test.js:456` (also 491, 519, 547 and 574). The same window-open scaffold is repeated five times, and the width test reimplements the `compareWithNewLabels` loop. The review suggested async tests, an `openWindow(win)` helper and a per-step mutation callback.

**Evidence inspected.** The five tests, `afterEach`, and mocha 8.4.0 promise handling.

**Verdict: confirmed.** Cleanup was already sound, so this was a clarity issue.

**Fix.** Added `openWindow` and `compareWithNewLabel`, and made the tests `async function`, which is new for `it` in this suite and which ran correctly here, including rejections. Step tables and each test's setup stay explicit, with the same step lists.

**Validation.** Broken builds still fail 4 and 3 tests, as before the refactor. `oxlint` is clean.

### R9: Documentation contains transient PR status

**Original claim.** `maintainer-docs/ios-label-text-measurement.md:115`. The doc records CI and CLA state that is already out of date or will go stale. The review suggested keeping rationale, invalidation rules and carry instructions in the repo, and leaving run-by-run status in the PR.

**Evidence inspected.** The maintainer doc and current PR checks.

**Verdict: confirmed.** One bullet and one clause recorded live status, and "first commit of this PR" was already out of date.

**Fix.** Replaced them with how the workflows behave. Rationale, reproducible instructions and dated benchmarks stay. Live status belongs on the PR, and this file's results are a dated record.

### R10: Repository contribution conventions

**Original claim.** `AGENTS.md:23`. The PR title has no `[ID]` prefix, the description links no issue and the two commits are not squashed. The first commit's message quotes the 185 to 49 ms figure without the 40 ms cutoff.

**Evidence inspected.** `AGENTS.md`, `CONTRIBUTING.md`, the PR template, `.husky/commit-msg`, repository settings and upstream PR titles.

**Verdict: partially confirmed.** Only the first commit's wording stands.

- **`[ID]` title prefix:** the template's ID is an upstream discussion number, and none exists for this fork-only change. `CONTRIBUTING.md` requires the title to be a conventional commit, which a prefix would break. Upstream's last 15 merged titles have none. Title kept, no ID invented.
- **Linked issue:** issues and discussions are disabled on the fork, so there is nothing to link. Repository settings weren't changed.
- **Squash:** `CONTRIBUTING.md` asks for added commits rather than squashing during review, and squashes on merge. Two or more commits are not a violation.
- **First commit:** its message quotes 185 to 49 ms without the 40 ms cutoff. A default squash copies commit messages into the body, so **whoever merges must use the message in the PR description**. No force-push was used.

**Limitation.** `AGENTS.md` still states the `[ID]` and linked issue rules, which conflict with `CONTRIBUTING.md` here. It wasn't changed, because that is outside this review.
