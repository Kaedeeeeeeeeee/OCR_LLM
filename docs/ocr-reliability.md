# OCR model failures: investigation and recovery

Date: 2026-09-17. Tested on Apple M1 Max, macOS 27.0 (26A428), Xcode 27.0 (27A266a).
Local fix: Cheese! OCR 1.1, build 7.

## Evidence and limits

The installed build 6 process had been running since 00:43. At 22:21 and 22:26,
200×128 and 370×166 screenshots reached Vision and failed after 0.040 s and
0.010 s. These were not screenshot permission failures or 20-second timeouts.
The same-time system logs contained:

- `aned`: `cachedModelFilePath=<private> does not exist`
- `aned`: model load failed, `com.apple.appleneuralengine Code=16`
- TextRecognition: E5RT precompiled compute operation failed, code 13
- App: `TextRecognition.CRImageReaderError error 1`

Restarting the same installed build completed its actual Vision warm-up in
2.929 s. Fresh standalone Vision processes recognized synthetic images in about
0.2 s once models were ready. Recreating VNRecognizeTextRequest and
VNImageRequestHandler within the original app was already its existing behavior;
this did not recover the two recorded failures. This supports a process-lifetime
native model/cache state problem, rather than an OCR request object needing reuse.

The logs redact the missing pathname. We have **not identified who removed or
invalidated the cache**, reproduced the original cache eviction, or established
that this affects every macOS 27 device. App source only removed its own capture
PNG; it contained no model-cache deletion. We did not clear system/model caches
or modify system daemons during this investigation.

A separate cold-start test showed VNRequest.cancel() scheduled at 20 s returning
only around 34 s later. Native model initialization can outlive a cooperative
cancellation request. Sandbox helper tests also exposed cold model compilation
lasting about 35 s. Consequently a fresh process for *every* image was rejected:
it can repeatedly pay that cost. The final design keeps one warmed helper and
restarts it only when needed.

## Final behavior

- The menu bar app owns a dedicated signed `CheeseOCRWorker` executable.
  Vision work lives entirely in this process, which inherits the app sandbox.
- Normal requests reuse warmed models. Language settings remain accurate mode,
  automatic language detection and correction, with Japanese, simplified and
  traditional Chinese, English and Korean available.
- The observed CRImageReader error and underlying ANE code 16 cause one automatic
  restart/retry. Abnormal helper exit also gets one retry. Persistent errors stop
  after two attempts; malformed images and unrelated errors are not blindly retried.
- Normal recognition has its requested deadline (currently 20 s). Startup
  warm-up has 60 s. One recovery attempt gets a bounded 60 s cold-start allowance.
  An initial request may wait for the bounded startup warm-up before recognition.
- Timeout/cancellation kills the helper from outside Vision; it cannot leave a
  permanently busy OCR actor. Termination notifications replace Foundation's
  run-loop-dependent waitUntilExit, with a bounded wait during cleanup.
- Commands travel through a local pipe. Images/results use per-request private
  temporary directories (0700), removed after completion, failure or cancellation.
  The helper exits on parent pipe EOF and has a parent-liveness watchdog.
- Logs include request IDs, attempts, duration and original error domains/codes.
  They do not include screenshots or recognized text.
- The worker contains fault injection only in Debug builds. Release binaries were
  inspected to confirm the test environment switches are absent.

## Regression verification

Run from the repository root:

```sh
./script/test_ocr.sh
```

The final functional run passed all 9 tests in 36.646 s (including cold model initialization):

1. Model failure retries in a different PID, and screenshot/result files are removed.
2. Persistent model failure stops after two attempts.
3. Invalid image input is rejected.
4. Unrelated errors do not retry.
5. Killed worker is replaced and the request recovers.
6. Twenty successive crash/recovery cycles complete without blocking cleanup.
7. Worker ignoring SIGTERM is force-terminated at deadline; the next real OCR succeeds.
8. Cancellation terminates the worker and removes temporary files.
9. Real OCR: 5 language samples × 3 rounds, all 5 again with the app's default
   automatic detection, a 200×128 crop and an empty image. Text assertions passed.

This covers 23 real image recognitions (22 in the multilingual test and one after
a timeout). The small synthetic images took roughly 0.03–0.15 s once warmed;
these timings are not a benchmark for large or complex screenshots.

The installed Release app successfully completed its real Vision warm-up in
0.450 s. The final source passed the regression suite and the universal Release build.
The user subsequently confirmed that the installed app works in actual use. This
manual confirmation is separate from the engine and fault-injection tests: the
desktop automation interface did not reliably trigger the Carbon global shortcut.

Fault injection verifies the **recovery behavior** for the observed error, not the
OS mechanism that originally invalidated the model cache. No 22-hour soak test or
second machine/OS version test has been completed.

## Build and signing

The Release build is universal (arm64 + x86_64) and passes
`codesign --verify --deep --strict`. Both app and worker use the same development
team. The worker is signed with only `com.apple.security.app-sandbox` and
`com.apple.security.inherit`; base debug entitlements are disabled for this target.

Xcode 27's test-build pipeline injects extra test-host entitlements into every
macOS entitlements payload, including an inheriting helper. Those extra keys
prevent correct sandbox inheritance. The test script builds for testing, restores
the helper's normal two-entitlement signature with the same signing identity,
re-signs the containing test app preserving its metadata, and uses
`test-without-building`. Production builds need no such adjustment.

References:

- [Apple: Embedding a command-line tool in a sandboxed app](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)
- [Swift Build: ProcessProductEntitlementsTaskAction, applyTestingEntitlementsIfNeeded](https://github.com/swiftlang/swift-build/blob/main/Sources/SWBTaskExecution/TaskActions/ProcessProductEntitlementsTaskAction.swift)

Build 7 was installed locally at `/Applications/Cheese! OCR.app`. Build 6 was
preserved in `.derivedData/Backups/Cheese! OCR-1.1-build6.app`. This investigation
verified the local fix; App Store release preparation is tracked separately.
