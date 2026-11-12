# Upstream sync, 2026-11-11

Merges `tidev/titanium-sdk` `main` into the fork's `master` line on branch `integration/upstream-sync`, together with the fork fixes merged into `master` since (PRs #3 and #5) and the CocoaPods clean-build fix. The 13.4 maintenance branches are untouched.

The branch keeps upstream's history. Merge it into `master` with a merge commit; a squash or rebase would drop upstream ancestry and make the next sync re-merge these commits.

## Revisions

| | Commit |
|---|---|
| Fork base (`origin/master` at the first merge) | `fac879d4f5a1e0ff170cbbedd054afad0aaf96a3` |
| Upstream (`upstream/main`, `tidev/titanium-sdk`, default branch `main`) | `d0e238f17eda3c3605f20d3eb9b5099c772a3fc1` (14.1.0) |
| Merge base | `b0027631bbbf62c2dc9537eb32916ee3a67883dc` |
| Merge commit | `93de1e9d566af42d1a96d0a1d94f390f71c44108` |
| Fork `origin/master` at the second merge | `5cff688b3acf7321457f1fc5cb3c88f4cbfcecbb` (PR #3 `0080812728`, PR #5 `5b8d3e6edf`) |
| Merge of fork `master` | `02687c6ea428b56327e433f302f12a959f421a93` |
| CocoaPods clean-build fix | `6c773886ab11764af56fdbff11b0e4371290b61d` (branch `fix/ios-hyperloop-pods-clean`) |
| Merge of the fix | `56ec137e42d4b5566f86c1b247313e8a55f96153` |

At the first merge the fork was 1 commit ahead and 20 behind, and local `master` had no unpublished commits. Fork `master` then gained PRs #3 and #5. At the second merge local `master` equalled `origin/master`, again with no unpublished commits.

## Incoming changes

20 upstream commits. Relevant to the fork:

- **Kroll/JSC and lifecycle (iOS):** `KrollContext destroy` detaches the global `Kroll` object's private pointer before releasing the context. `KrollTimerManager dealloc` no longer releases its timer table twice (crash during `Ti.App._restart()`). `TiUIWindowProxy _destroy` does not close a window again from the dealloc-time `_destroy`. `TiUIButtonProxy _destroy` detaches the bar button item from the proxy. `TiViewProxy` `children` and `removeAllChildren:` return early when `childrenQueue` is `NULL`.
- **Layout:** `TiUtils frameForController` sizes to the window bounds. `TiViewController` extends the bottom edge for the iOS 27.1 vertical tab bar. `TiRootViewController` drops the upside-down frame adjustment and stops retrying denied geometry requests until the next size transition. `TiUIView` adds `borderDashPattern` and fixes the border width doubling on every `borderColor` set.
- **Animation:** `54848a1f0f` adds `Matrix2D.rotate(from, to)` and changes `TiAnimation`: `applyProperties:` now runs only when the animation finished (`TiAnimation.m:300`). An interrupted animation no longer writes its target values to the proxy.
- **Text measurement:** none. Upstream does not touch `TiUILabel`, fonts or `sizeForFont:`.
- **Push:** the cached remote notification is cleared once delivered, so it is not replayed.
- **Build and toolchain:** version 14.1.0. ioslib 6.0.2, liveview 1.6.0, mocha 12, glob 14, npm overrides for audit findings. The iOS CLI removes duplicate group membership for extensions (Xcode 27.2). CI moved to Node 26; `vendorDependencies.node` is still `>=22.19.0`. Minimum iOS is still 16.0 (from 14.0.0). No new deployment-target change.
- **Module packaging (`dc5bdda112`):** the SDK no longer bundles any native module except Hyperloop, which goes from 8.0.1 to 8.0.2. Removed: ti.map, ti.identity, facebook, urlSession, ti.coremotion, ti.webdialog, ti.applesignin, ti.playservices.
- **Android:** stops forcing a V8 GC after every `TiBlob` image operation, caches property name strings, Material 1.14.0, accepts quoted keystore paths.
- **Public API:** additions only: `Ti.UI.View.borderDashPattern`, `Ti.UI.Matrix2D.rotate(from, to)`. No removals.
- CHANGELOG, README, release workflows and CI. Upstream `9092aef624` also bumps `.github/workflows/cla.yaml` from `tidev/tidev-cla-action@v2` to `@v3`, as part of moving actions off the Node 20 runtime. The merge carries it unchanged; the fork adds no CLA or security workflow change of its own.

## Conflicts

None in either merge.

- **Upstream merge:** the fork's paths and upstream's paths do not overlap. The independent review checked the tree mechanically: `git diff fac879d4f5 93de1e9d56` equals `git diff b0027631bb d0e238f17e`, and `git diff d0e238f17e 93de1e9d56` equals `git diff b0027631bb fac879d4f5`.
- **Fork `master` merge:** PRs #3 and #5 change `iphone/Classes/TiUITableView.m`, `iphone/TitaniumKit/TitaniumKit/Sources/API/TiBlob.m` and `tests/Resources/ti.blob.test.js`. Upstream does not touch any of them (`git diff b0027631bb d0e238f17e` is empty for these paths). After the merge all three files, and `TiUILabel.{h,m}`, are identical to `origin/master`.

## Fork patches

| Patch | State |
|---|---|
| `fac879d4f5` TiUILabel measurement cache | Preserved unchanged. Upstream has no equivalent and no second cache. |
| TiViewProxy queue lifetime | Already on the merge base through upstream `32df010365`: the queues are released in `dealloc`, after a final `_destroy`. The 13.4 backport (`titanium-carbon-134-view-queue-lifetime`, uncommitted) is separate and not part of this merge. |
| TiUITableView header and footer proxy retention (PR #3, `0080812728`) | Merged from fork `master`, unchanged. |
| TiBlob ArrayBuffer exception out-param and allocation check (PR #5, `5b8d3e6edf`) | Merged from fork `master`, unchanged, with its tests. The defect remains upstream. |
| CocoaPods clean-build fix (`6c773886ab`) | Added here. See [ios-hyperloop-cocoapods-clean.md](./ios-hyperloop-cocoapods-clean.md). |

## Known remaining defects

- **Blob tests on iOS:** `tests/Resources/app.js` still loads `ti.blob.test` on Android only, so the normal iOS suite does not run the ArrayBuffer tests from PR #5. They were run on iOS separately (see Checks).
- **TiViewProxy guard comments:** the new `childrenQueue == NULL` guards (`TiViewProxy.m:71`, `:362`) say the queue is released in `_destroy`. On this tree it is released in `dealloc`. The guards are harmless and the comments are wrong; left as upstream wrote them.
- **`TiAnimation` interrupted animations** (`TiAnimation.m:300`): intended upstream behaviour, but it changes what JS reads back after an interrupted animation. Apps that read `opacity`, `top` and similar after a cut-short animation should be checked.
- **`Ti.UI.Matrix2D.apiName`** returns `Ti.UI.2DMatrix`. The test fails on upstream and on the fork base too.
- Lower-severity review findings are listed under Independent review.

## SDK build

Toolchain: Xcode 26.2 (17C52), Node 22.23.4, npm 10.9.9, macOS 26.2. No toolchain change was needed. Android was not built: there is no Android SDK on this machine.

```bash
npm ci
node ./build/scons build ios
node ./build/scons package ios --version-tag 14.1.0.USYNC --skip-zip
cp -R dist/mobilesdk-14.1.0.USYNC-osx/mobilesdk/osx/14.1.0.USYNC "$HOME/Library/Application Support/Titanium/mobilesdk/osx/"
```

`scons install` was not used, because it copies the packaged `modules/` over the shared `~/Library/Application Support/Titanium/modules` directory. The shared Hyperloop directory still has only 7.0.6, 7.0.9, 7.1.0 and 8.0.1. The CLI's selected SDK is still 13.4.0.GA.

Artifact: `manifest.json` reports `name 14.1.0.USYNC`, `version 14.1.0`, `githash 93de1e9d56`, platform `iphone`. `iphone/Classes/TiUILabel.{h,m}` in the SDK match the merge commit. `TitaniumKit` contains the upstream symbols (`clearRemoteNotification`, `borderDashPattern`, `deniedGeometryTarget`).

Baseline SDKs, built the same way from detached worktrees: `14.1.0.USYNCUP` (upstream `d0e238f17e`) and `14.0.0.USYNCFORK` (fork base `fac879d4f5`).

The final tree was built the same way as `14.1.0.FORKSYNC`, with a clean worktree. Its `manifest.json` reports `name 14.1.0.FORKSYNC`, `version 14.1.0`, `githash 4e439ba95b`. That commit was later recreated as `56ec137e42` so the published history would not carry local paths and private app details; outside `maintainer-docs/` the two trees are identical. Checked in the artifact:

- `iphone/Classes/TiUITableView.m`, `TiUILabel.m` and `iphone/cli/commands/_build.js` are identical to the tree, and `_build.js` has no `cleanXcodeDerivedData`.
- `TiBlob.m` was recompiled. Every `TitaniumKit.xcframework` slice contains the PR #5 error string, which `14.1.0.USYNC` lacks.
- The kernel `common/Resources/ios/ti.kernel.js` is byte-identical to `14.1.0.USYNC`.

SDK 14 needs Titanium CLI 9.1.0 or newer. The global CLI is 7.1.5 and refuses to build. Everything here used the repository's `node_modules/.bin/titanium` (9.1.0).

## Checks

The first table covers `14.1.0.USYNC` (the upstream merge alone). The final tree has its own table below; it reruns the checks the later changes could affect.

| Check | Result |
|---|---|
| `npm run lint:js`, `lint:objc`, `lint:docs` | Pass (warnings only) |
| `lint:swift` | Not run: `swiftlint` is not installed |
| `lint:android`, Android build and tests | Not run: no Android SDK |
| `npm run test:cli` | 85 passing. `android/cli/tests/test-keystore-path.js` alone: 20 passing |
| commitlint on the merge message | Pass |
| `tests/native/ios/run.sh`, iPhone 17 / iOS 26.2 | 21 executed, 21 passed (2 `LabelMeasurementTests`, 19 `SceneTests`), from the result bundle |
| iOS JS suite, full | 2,468 started, 2,608 results: 2,442 passed, 25 failed, 141 pending. Mocha stopped early after an uncaught failure, before `ti.ui.label.test` |
| iOS JS suite, without `ti.ui.ios.splitwindow.test` | 3,253 started: 3,186 passed, 67 failed, 217 pending |
| Same scope on fork base `14.0.0.USYNCFORK` | 3,244 started: 3,181 passed, 64 failed, 217 pending |
| Same scope on upstream `14.1.0.USYNCUP` | 2,488 started: stopped at `Titanium.UI.Layout` after an uncaught failure |
| Upstream, ListView, ScrollableView, TableView, View, WebView and Window files only | 236 started: 200 passed, 24 pending, 36 failed (27 of them `pixelmatch`) |
| `ti.ui.label.test` only, 3 runs | 29 passed, 2 pending, 1 failed (`.textid`, locale) in each run |
| `ti.geolocation.test` only, 2 runs each on `14.1.0.USYNC` and `14.0.0.USYNCFORK` | 75 started: 73 passed, 1 pending, 2 failed (`getCurrentPosition`, `kCLErrorDomain error 0`), identical on both |

### Final tree (`14.1.0.FORKSYNC`)

The full iOS JS suite was not rerun. The later changes are TableView, TiBlob, the build CLI and docs, so the focused suites below cover them, and the full-suite evidence above stands for everything else.

| Check | Result |
|---|---|
| `npm run lint:js`, `lint:objc`, `lint:docs` | Pass (warnings only; the one `_build.js` warning, unused `once`, predates this work) |
| CLI tests (`cli/tests`, `iphone/cli/tests`, `android/cli/tests`, `build/lib/test`) | 85 passing |
| commitlint on every new commit | Pass |
| `tests/native/ios/run.sh`, iPhone 17 / iOS 26.2 | 21 executed, 21 passed (2 `LabelMeasurementTests`, 19 `SceneTests`), from the result bundle |
| `ti.blob.test` on iOS, guard removed in the generated app | 81 results: 80 passed, 1 pending, 0 failed, completed with the stop marker. All 12 `toArrayBuffer()`/`arrayBuffer()` tests ran and passed |
| Same on `14.1.0.USYNC` (without PR #5) | App exits after 75 passed, no stop marker: the defect the tests catch |
| `ti.ui.tableview.test`, 2 runs, and 2 more with `NSZombieEnabled` | 47 started per run: 40 or 41 passed, 7 pending, 6 or 7 failed. The 6 are `pixelmatch is not a function`. The 7th is `contentOffset` (88 instead of 150), in 3 of 4 runs. No zombie message, no crash |
| Same on `14.1.0.USYNC` (without PR #3), 3 runs | `contentOffset` fails in all 3, and `.searchText` once. A baseline failure, not caused by PR #3. The test uses no header or footer view |
| `ti.ui.label.test`, 2 runs | 29 passed, 2 pending, 1 failed (`.textid`, locale), as before |
| CocoaPods reproducer (`zo0m.test.hlpods`), forced clean simulator build | Pod products kept, both classes in the metabase, no `xcodebuild clean`. Runs: `objc=objc-hello-ti swift=5` |
| Reproducer, incremental build | Build directory reused. Runs with the same result |
| Reproducer, pod source changed, then a forced clean build | Runs the changed implementation (`objc=objc-changed-ti`) |
| Reproducer, device target (test deploy type), build only, development profile | Pod products kept, both classes in the iphoneos metabase |
| Production deploy type (`dist-adhoc`, `dist-appstore`) | Not built: no distribution certificate on this machine. Covered by the code path, which no longer differs by deploy type, and by the resolved clean locations in the fix record |
| FireCloud, forced clean simulator build | See FireCloud compatibility |

Two Hyperloop 8.0.2 cache defects showed up in the reproducer:

- After an earlier failed build, `build/hyperloop/ios/symbol_references.json` lacked the pod classes. The next build logged "Symbol references up-to-date" and skipped binding generation, so the app failed with `Requested module not found: ZTObjC/ZTGreeter`. `ti clean -p ios` does not remove `build/hyperloop`; `ti clean` does, and the rebuilt app ran.
- A clean device build right after a simulator build reused the cached `metabase-cocoapods-*.json`. That file pointed at `Debug-iphonesimulator` headers, which the clean build had removed, so the iphoneos metabase had no pod classes. From a `ti clean` state the device metabase is complete. The step that deleted the headers is `initBuildDir()`, so the removed Xcode clean was not involved.

### How the JS suite was run

`npm run test:iphone` (`build/lib/test/test.js`) runs `killall Simulator`, which quits the Simulator app other sessions use, and then waits for the CLI to launch the simulator. With the Simulator app already open on another session's device, that launch never finished. So the repository runner generated and built the test app (with a no-op `killall` on `PATH`). A separate script then installed the app on a dedicated simulator, launched it, and read the app's own log file (`Documents/<guid>.log`, written because simulator builds set `LOGTOFILE`). Counts come from that file's `!TEST_START`/`!TEST_END` lines and the `!TEST_RESULTS_STOP!` marker.

Mocha stops the whole run when an uncaught assertion fails asynchronously. It then still prints the stop marker, so the marker alone does not prove a full run. `ti.ui.ios.splitwindow.test` produced the first such failure, so the comparison runs exclude that file in the generated project. Clipboard tests also leak uncaught failures into later tests, including the label auto-size tests. The label-only runs show those tests pass on their own.

The iOS suite does not run `ti.blob.test` or `ti.media.videoplayer.test`: `app.js` loads them on Android only. In the full-suite runs above, no Blob or VideoPlayer test was executed on iOS.

The focused runs on the final tree use the same generated project. A script comments out every other test module in its `app.js`, removes the `OS_ANDROID` guard around `ti.blob.test`, and sets the app id to `zo0m.test.forksync.mocha`.

### Failure attribution

All failures in the integration run, by cause:

- **Also fail on the fork base and, where the upstream run reached them, on upstream:** Date and Intl formatting, `util.format %o`, Buffer UTF-16, Codec byte order, both HTTPClient network tests, `overrideUserInterfaceStyle`, Semantic Colors, `Matrix2D.apiName`, Clipboard (3), `createLivePhotoBadge`, Window `safeAreaPadding` (2), ListView `scrolling event`, WebView (3, network), Label `animate font color`.
- **Environment:**
  - `pixelmatch is not a function`: all snapshot tests, on every build.
  - `titleid`/`textid`: the simulator locale is `en_UA`, so iOS picks the fixture's `en-GB` strings.
- **Leaked uncaught failures:** label auto-size tests in the combined runs, on both builds. They pass alone.
- **Fork base only:** `TableView contentOffset` (known intermittent), Layout `viewSizeAndRectPx` (leak).
- **Integration only, in the combined runs:**
  - Four Geolocation timeouts (`getCurrentHeading`, `requestLocationPermissions`). They came from the first launches on a newly erased simulator.
  - In the isolated Geolocation runs, both builds give the same result: the same 2 `getCurrentPosition` failures, because the simulator has no location set.

No failure is attributed to the merge.

## FireCloud compatibility

A separate FireCloud worktree, detached at the app's current development head. App id `zo0m.test.firecloud.usync`, set through environment variables, not `.env`. Dedicated iPad Pro 11-inch (M5) simulator, iOS 26.2.

Local-only changes in that worktree:

- FireCloud's native JSON workaround: a reviewed allowlist entry for `14.1.0.USYNC` (kernel SHA-256 `cffe5593…4817`). The kernel differs from 13.4.0.GA only in `runMain`, which decides whether the launch script or an earlier service is the main module. JSON is not involved. `ti.main.js` (core-js 3.50.0) still forces the JSON wrapper when `JSON.rawJSON` is not native, so the workaround is still needed.
- `modules/iphone/hyperloop/8.0.2` from the SDK package, so the shared modules directory stays unchanged.

| Step | Result |
|---|---|
| `npm run test:native-json` | 23 passed |
| `gulp buildComponents`, `pod install` | Pass. 15 pods |
| JS compile, Alloy, native JSON generation | Pass. The generated `ti.kernel.js` ends with the SDK kernel bytes unchanged (SHA-256 matches). `0-native-json.bootstrap.js` generated |
| Hyperloop CocoaPods build | `BUILD SUCCEEDED` |
| Hyperloop custom class generation | **Failed on `14.1.0.USYNC`:** `unknown encoding [MapView] start at index 0` (`hooks/generate/custom.js:221`), exit 13 |

The cause was the SDK's forced `xcodebuild clean` deleting the pods Hyperloop had just built. It affects every 14.x SDK, including clean upstream; see [ios-hyperloop-cocoapods-clean.md](./ios-hyperloop-cocoapods-clean.md).

With `14.1.0.FORKSYNC`, in the same worktree (local `14.1.0.FORKSYNC` allowlist entry for the identical kernel, `tiapp.xml` switched there only):

| Step | Result |
|---|---|
| `npm run test:native-json` | 23 passed |
| Forced clean simulator build | Pass. The metabase has MapboxMaps 4, GCDWebServer 15 and 30 classes from the app's three local Swift pods, including `MapView`, the same as 13.4. Native JSON kernel override generated from `14.1.0.FORKSYNC` |
| Startup on the dedicated iPad simulator | Reaches the login screen, no `[ERROR]` lines. `[native-json]` reports `stringifyIsCaptured: true, parseIsCaptured: true`. The app's data container was kept from an earlier install, so this was not a fresh-install start |
| Signed-in inspection form and map | Not tested: no signed-in session with synthetic data |
| Physical device | Not tested |

A fresh install on `14.1.0.HLFIX` logged errors from a FireCloud database migration. This is FireCloud code, independent of the SDK.

## Independent review of the upstream merge

A separate reviewer read the merge without being given these conclusions.

- **Tree:** exact, as above.
- **Medium:**
  - The module packaging removal affects FireCloud's `ti.map` and `ti.identity`.
  - The `TiAnimation` interrupted-animation change.
- **Low, plausible:**
  - `TiUINavBarButton` spinner `activityDelegate.proxy` can still dangle after the proxy is freed. This existed at the merge base.
  - The `TiRootViewController` geometry error handler uses an unretained `blockSelf` (MRC). The same pattern exists elsewhere in the file.
  - The Xcode 27.2 group de-duplication can double an extension framework's path prefix when its Frameworks group sits inside its target group.
  - `clearRemoteNotification` clears the shared launch payload for every scene.
- **Info:** `kTiFrameAdjustNotification` is no longer posted anywhere.
- **Confirmed correct:** the KrollTimerManager, KrollContext, TiUIWindowProxy and TiUIView changes. No interaction with the label cache.

## Independent review of the final tree

A fresh reviewer read the combined diff against fork `master` and both later merges. No blockers.

- **Merges:** each merge commit equals its clean automatic merge, recomputed with `git merge-tree --write-tree`. Against the ideal merge of `5cff688b3a` and `d0e238f17e`, HEAD differs only in `iphone/cli/commands/_build.js` (the fix) and `maintainer-docs/`. No fork file is lost or altered.
- **Interactions:** upstream does not touch iOS `TiBlob`, `TiUITableView` or label measurement. Its `TiViewProxy` `childrenQueue == NULL` guards and the `KrollContext` private-pointer detach make PR #3's longer-lived header and footer proxies safer during teardown. Neither makes a fork fix redundant.
- **Fix:** correct for all targets. The removed step's only side effect, recreating `xcodeAppDir`, is already done by `initBuildDir()`.
- **Hygiene:** no build artifacts, credentials or experiments. Commit messages are conventional.
- **Should-fix, applied:** the fork is public, so the records no longer carry local machine paths, FireCloud's private pod names or its internal source references.
- **Nits:**
  - The fix commit cites `#13032`, which is upstream `tidev/titanium-sdk#13032`, not a fork PR.
  - The comment above `initBuildDir()` describes a step that no longer exists. It is kept on purpose, as a guard against adding the step back.

## Status

- **SDK integration:** iOS validated as listed above. Android is unbuilt and untested here: there is no Android SDK on this machine. `lint:swift` was not run: `swiftlint` is not installed.
- **FireCloud on 14.1:** builds and starts with this SDK. Switching FireCloud's SDK is a separate change that still needs:
  - Titanium CLI 9.1.0 or newer for FireCloud builds.
  - `ti.map` and `ti.identity` vendored or pinned, since the SDK no longer ships them.
  - Acceptance of the iOS 16.0 minimum (FireCloud documents 15.6).
  - A reviewed kernel hash in source, and the native JSON workaround's device checks.
  - Signed-in smoke tests of inspection forms and maps, on simulator and device.
  - A fix for the fresh-install database migration.
- **Hyperloop (separate repository):** it discards the metabase generator's stderr, and the generator exits 0 after a fatal parse error. Its cache also has the two defects described under Checks.
