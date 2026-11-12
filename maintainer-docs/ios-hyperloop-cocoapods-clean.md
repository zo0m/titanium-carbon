# iOS: Hyperloop loses CocoaPods classes on clean builds (SDK 14)

Investigation of 2026-11-11. The fix removes the iOS builder's forced `xcodebuild clean`. Validation of the combined fork tree is recorded in [upstream-sync-2026-11-11.md](./upstream-sync-2026-11-11.md).

## Symptom

FireCloud on 14.1 stopped in Hyperloop generation with `unknown encoding [MapView] start at index 0` (`hooks/generate/custom.js:221`). Its main metabase had no class from any pod (MapboxMaps 0, GCDWebServer 0, and 0 from the app's three local Swift pods). On 13.4 the counts were 4, 15 and 30. `MapView` was not the cause. It was the first pod class the custom-class generator looked up.

## Root cause (Titanium SDK)

1. During `build.pre.compile`, Hyperloop builds the pods with `xcodebuild ... SYMROOT=<project>/build/iphone/build/Products` (`hyperloop-metabase/lib/metabase.js`, `runCocoaPodsBuild`).
2. `copyTitaniumiOSFiles()` installs `iphone/iphone/Titanium.xcodeproj/xcshareddata/WorkspaceSettings.xcsettings` into the generated project's per-user `xcuserdata` for every non-production build. This came from upstream `07b72f89fe` (#13032), and every 14.x SDK has it; no 13.x SDK does. The settings set Xcode's build products to `Build/Products`, relative to the workspace. On a case-insensitive volume that is the same directory as the CLI's `SYMROOT`.
3. On a clean (forced) build, `cleanXcodeDerivedData()` then ran `xcodebuild clean -scheme <app>`. That command has no location arguments, so it cleans Xcode's own build location for the scheme. With those settings, that is `build/iphone/Build/Products`, and the clean deleted every pod framework Hyperloop had just built.
4. During `build.pre.build`, Hyperloop generates the metabase from a header that imports the deleted pod headers. Clang stops at the first one (`fatal error: '.../<Pod>.framework/Headers/<Pod>-Swift.h' file not found`). The `metabase` binary still exits 0 and writes system-only JSON, and Hyperloop discards its stderr. Generation then fails at the first pod class (FireCloud), or the app fails to link against the missing pod frameworks (reproducer).

Incremental builds don't run the clean. That is why a build directory that already holds pods can look fine.

### Evidence

- **Timeline:** in the failing FireCloud build, the pods built (`BUILD SUCCEEDED`). `WorkspaceSettings.xcsettings` was created at 20:06:41. `build/iphone/build/Products` was recreated at 20:06:43, right after `Cleaning Xcode derived data`. The metabase ran at 20:07:21.
- **A/B experiment:** pods built by hand with Hyperloop's command, then the SDK's exact clean command run:
  - With the settings file present, `ZTGreeter.h` is deleted.
  - With the settings file moved aside, it is kept.
- **Manual generator run:** the metabase binary run with the failing build's exact arguments gives exit 0, 66 MB of JSON, and a fatal clang error on stderr.
- **Clean upstream SDK:** the reproducer fails the same way, so this is not caused by the fork or the merge.

## Comparison

Same reproducer and the same pinned toolchain for every row. Each row is a forced clean simulator build.

| SDK | Pod frameworks after build | `ZTGreeter` / `ZTSwiftCounter` in metabase | Result |
|---|---|---|---|
| 13.4.0.GA (`88e381cd0c`) | kept | yes / yes | builds |
| 14.1.0.USYNC (`93de1e9d56`, fork + upstream) | deleted | no / no | link fails |
| 14.1.0.USYNCUP (`d0e238f17e`, clean upstream) | deleted | no / no | link fails |

Both SDK lines run the clean. On 13.4 it resolves to Xcode's default DerivedData location and never touches the CLI's build directory. Results for the fixed SDK are in the upstream sync record.

## Where the clean resolved

`xcodebuild -showBuildSettings -scheme HLPods -destination 'generic/platform=iOS Simulator'` in the reproducer's generated project, which resolves the same locations as the clean:

| Configuration | `SYMROOT` the clean resolves to |
|---|---|
| Workspace settings present (development, test) | `build/iphone/Build/Products`, the CLI's `SYMROOT` |
| Settings absent, default Xcode preferences (production) | `~/Library/Developer/Xcode/DerivedData/HLPods-<hash>/Build/Products` |
| Settings absent, Xcode Locations set to Custom, relative to workspace (production) | `build/iphone/Build/Products`, the CLI's `SYMROOT` |

The third row was produced with argument-domain overrides (`-IDEBuildLocationStyle=Custom -IDECustomBuildLocationType=RelativeToWorkspace -IDECustomBuildProductsPath=Build/Products`), not by changing the user's Xcode preferences.

So the clean either cleaned a directory the CLI build never reads, or deleted this build's own pod products. It never removed anything a later step needed.

## Reproducer

A standalone test app, bundle `zo0m.test.hlpods`. It is kept outside the repository.

- **Hyperloop:** 8.0.2, vendored from the SDK package.
- **Pods:** two local pods, `ZTObjC` (plain Objective-C `ZTGreeter`) and `ZTSwift` (a Swift `@objc` class `ZTSwiftCounter`).
- **`app.js`:** calls both classes, writes the results to `hlpods-result.txt` and logs `HLPODS_RESULT`.

It affects all pods, both Objective-C and Swift. It is not specific to Mapbox, modular frameworks or one architecture.

## Fix

`iphone/cli/commands/_build.js`: the `cleanXcodeDerivedData()` step and its call in `run()` are removed for every target and deploy type. A comment at `initBuildDir()` records why.

Why removing it is safe:

- A clean build is `forceCleanBuild`. It is set only before or inside `initBuildDir()`, which empties the build directory when it is true, or creates it and sets it.
- The Xcode build passes `-derivedDataPath <buildDir>/DerivedData`, `OBJROOT`, `SHARED_PRECOMPS_DIR` and `SYMROOT`, all inside the build directory, for every target, including `archive` for `dist-*`. Module caches and Swift package checkouts follow `-derivedDataPath`. `xcodeAppDir` is inside the build directory and is recreated by `initBuildDir()`, which made the method's own `ensureDirSync(xcodeAppDir)` redundant.
- Archives go to `~/Library/Developer/Xcode/Archives`; the clean never touched them.

What changes:

- Development and test clean builds keep the pods Hyperloop built (the defect).
- Production clean builds keep them too when the user's Xcode Locations preference is Custom, relative to the workspace. 13.4 also had this case.
- Production clean builds no longer clean `~/Library/Developer/Xcode/DerivedData/<app>-<hash>`, which the CLI build doesn't use. Opening the generated project in Xcode without the workspace settings uses that location, and Xcode's incremental build handles it.
- Incremental builds are unchanged; the step returned immediately when `forceCleanBuild` was false.
- A `build.pre.compile` plugin that sets `forceCleanBuild` would no longer get an Xcode clean. Nothing in this repository or in Hyperloop 8.0.2 sets it; Hyperloop only reads it.

### Alternatives not taken

- **Skip the clean only when the workspace settings are installed** (non-production). It was built and validated as `14.1.0.HLFIX` (including the FireCloud results below), but it keyed on the deploy type instead of the cause and still deleted the pods in the custom Xcode Locations case.
- **Pass the build's location arguments to the clean.** It would then only delete what `initBuildDir()` already emptied, plus Hyperloop's output.

There is no unit test: the change removes a step, and `_build.js` can't be loaded standalone. The reproducer is the regression check.

## FireCloud (isolated worktree, `14.1.0.HLFIX`)

For simulator builds, the narrow candidate and the final fix behave the same: neither runs the clean.

- **Setup:**
  - A separate FireCloud worktree, test bundle `zo0m.test.firecloud.usync`, dedicated iPad simulator.
  - Toolchain: Titanium CLI 9.1.0 (the worktree's own; the global 7.1.5 was not changed), Node 22.23.4, Xcode 26.2 (17C52), CocoaPods 1.16.2, Hyperloop 8.0.2.
  - Pods (Podfile.lock sha256 `8515e7e4…f3a9`): MapboxMaps 11.8.0, MapboxCoreMaps 11.8.0, MapboxCommon 24.8.0, Turf 3.0.0, GCDWebServer 3.5.4, QCropper 0.1.7, SQift 4.1.1, and the app's local pods.
- **Native JSON workaround:** a local `14.1.0.HLFIX` allowlist entry, in that worktree only. Its kernel is byte-identical to the reviewed `14.1.0.USYNC` kernel (sha256 `cffe5593…4817`). `npm run test:native-json` passes 23 of 23.
- **Build:** succeeds. The metabase holds MapboxMaps 4, GCDWebServer 15 and 30 classes from the app's three local Swift pods, including `MapView`, the same as 13.4.
- **Setup gap:** `@turf/distance` was not found at startup because the worktree had never installed `app/lib/node_modules`. `npm ci` from its lockfile fixed it. Not an SDK problem.
- **Modules:** `ti.map` 7.3.1 and `ti.identity` 5.0.0 resolve from the shared modules directory. SDK 14 no longer bundles them.
- **Startup:** reaches the login screen. The JSON workaround reports `stringifyIsCaptured: true, parseIsCaptured: true`.
- **Errors logged at startup:** a FireCloud database migration fails on a fresh install. This is FireCloud logic, independent of the SDK.
- **Not done:** signed-in inspection-form and map smoke tests, and a physical device.
- **Minimum iOS:** SDK 14 requires 16.0 (`iphone/package.json` `minIosVersion`). FireCloud's Podfile declares 15.6. FireCloud's deployment policy was not changed.

## Independent review

Two separate reviews, one per candidate.

- **Narrow candidate:** no blockers. It recommended removing the clean for every deploy type instead, because the deploy type only stands in for the cause and misses the custom Xcode Locations case.
- **Final fix:** no blockers. It confirmed:
  - the clean is redundant for simulator, device, `macos` and all `dist-*` targets;
  - nothing depends on the removed method's side effects, and nothing is left unused;
  - incremental builds are unaffected.
  Its comment wording notes (archives, the `Build/Products` case) were applied. Its remaining notes are the DerivedData and plugin points listed under What changes.

## Remaining, outside this patch

- **Hyperloop (separate repository):**
  - It discards the metabase generator's stderr, and the generator exits 0 after a fatal parse error, so a failed parse produces apparently valid metadata.
  - Its cache in `build/hyperloop` survives `--force`. After a metabase changes, "Symbol references up-to-date" skips stub and binding generation. One broken build therefore leaves stale `hyperloop.bindings.js` until `ti clean`.
- **FireCloud migration to 14.x:**
  - CLI 9.1.0 or newer.
  - Pin or vendor `ti.map` and `ti.identity`.
  - Accept the iOS 16.0 minimum.
  - Review and add the kernel hash in source.
  - Run the workaround's device checks.
  - Smoke-test inspection forms and maps signed in, on simulator and device.
