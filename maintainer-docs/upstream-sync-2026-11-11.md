# Upstream sync, 2026-11-11

Merges `tidev/titanium-sdk` `main` into the fork's `master` line on branch `integration/upstream-sync`. Not pushed, not merged into `master`. The 13.4 maintenance branches are untouched.

## Revisions

| | Commit |
|---|---|
| Fork base (`origin/master`) | `fac879d4f5a1e0ff170cbbedd054afad0aaf96a3` |
| Upstream (`upstream/main`, `tidev/titanium-sdk`, default branch `main`) | `d0e238f17eda3c3605f20d3eb9b5099c772a3fc1` (14.1.0) |
| Merge base | `b0027631bbbf62c2dc9537eb32916ee3a67883dc` |
| Merge commit | `93de1e9d566af42d1a96d0a1d94f390f71c44108` |

The fork was 1 commit ahead and 20 behind. Local `master` had no unpublished commits; it was 1 behind `origin/master`.

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

None. The fork's paths and upstream's paths do not overlap. The independent review checked the tree mechanically: `git diff fac879d4f5 93de1e9d56` equals `git diff b0027631bb d0e238f17e`, and `git diff d0e238f17e 93de1e9d56` equals `git diff b0027631bb fac879d4f5`.

## Fork patches

| Patch | State |
|---|---|
| `fac879d4f5` TiUILabel measurement cache | Preserved unchanged. Upstream has no equivalent and no second cache. |
| TiViewProxy queue lifetime | Already on the merge base through upstream `32df010365`: the queues are released in `dealloc`, after a final `_destroy`. The 13.4 backport (`titanium-carbon-134-view-queue-lifetime`, uncommitted) is separate and not part of this merge. |
| TiBlob ArrayBuffer exception out-param (`c2f6359f57`, 13.4 only) | Not imported. The defect remains upstream and here; see below. |

## Known remaining defects

- **TiBlob ArrayBuffer:** `TiBlob.m:484` (`toArrayBuffer`) and `:502` (`arrayBuffer`) pass an uninitialized `JSValueRef *` to `JSObjectMakeArrayBufferWithBytesNoCopy`. Unchanged upstream. The fix exists only on `fix/13.4-blob-arraybuffer`. The iOS suite does not cover it: `tests/Resources/app.js` loads `ti.blob.test` on Android only.
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

SDK 14 needs Titanium CLI 9.1.0 or newer. The global CLI is 7.1.5 and refuses to build. Everything here used the repository's `node_modules/.bin/titanium` (9.1.0).

## Checks

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

### How the JS suite was run

`npm run test:iphone` (`build/lib/test/test.js`) runs `killall Simulator`, which quits the Simulator app other sessions use, and then waits for the CLI to launch the simulator. With the Simulator app already open on another session's device, that launch never finished. So the repository runner generated and built the test app (with a no-op `killall` on `PATH`). A separate script then installed the app on a dedicated simulator, launched it, and read the app's own log file (`Documents/<guid>.log`, written because simulator builds set `LOGTOFILE`). Counts come from that file's `!TEST_START`/`!TEST_END` lines and the `!TEST_RESULTS_STOP!` marker.

Mocha stops the whole run when an uncaught assertion fails asynchronously. It then still prints the stop marker, so the marker alone does not prove a full run. `ti.ui.ios.splitwindow.test` produced the first such failure, so the comparison runs exclude that file in the generated project. Clipboard tests also leak uncaught failures into later tests, including the label auto-size tests. The label-only runs show those tests pass on their own.

The iOS suite does not run `ti.blob.test` or `ti.media.videoplayer.test`: `app.js` loads them on Android only. No Blob or VideoPlayer test was executed on iOS.

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
| Hyperloop custom class generation | **Fails:** `unknown encoding [MapView] start at index 0` (`hooks/generate/custom.js:221`), exit 13 |
| Startup, form, map smoke test | Not possible: no app was built |

The Hyperloop failure is the historical one, and it is not caused by this sync:

- 8.0.1 and 8.0.2 have identical hooks, and FireCloud on 13.4 also builds with 8.0.1.
- On 13.4, `MapView` comes from `MapboxMaps-Swift.h` in the main metabase. On 14.1 the main metabase (`metabase-16.0-…json`) has no class from any pod: 0 from MapboxMaps, GCDWebServer and the app's three local Swift pods, against 4, 15 and 30 on 13.4.
- The generated metabase header imports the same headers on both, and Hyperloop logged parsing `MapboxMaps-Swift.h` from the built pod framework.
- Root cause not established. The next step is to run the metabase generator by hand on `metabase-16.0-…h` with the same flags and read the clang diagnostics, then compare with 13.4.

## Independent review

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

## Status

- **SDK integration:** ready for a fork PR on iOS evidence. Android is unbuilt and untested here.
- **FireCloud on 14.1:** not ready. Its build stops in Hyperloop generation. Before changing FireCloud's SDK:
  - Find and fix why the 14.x Hyperloop metabase drops all CocoaPods classes.
  - Install Titanium CLI 9.1.0 or newer for FireCloud builds.
  - Vendor or pin `ti.map` and `ti.identity`, since the SDK no longer ships them.
  - Confirm that the iOS 16.0 minimum is acceptable (FireCloud documents 15.6).
  - Review the kernel hash and run the native JSON workaround's device checks.
  - Smoke-test startup, an inspection form and a map on a device.
