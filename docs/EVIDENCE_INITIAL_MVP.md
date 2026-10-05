# Initial MVP Engineering Evidence

## Identity

- Product: Price Lens
- Source commit: `e241b07059a9c494b3c83026274993d935c5c4ff`
- Branch at verification: `feat/initial-mvp`
- Standard baseline: AE Development Rules 8.0.0
- Standard commit: `132b7cd32873ba7328e3128ffbb33e1929b74d45`
- Delivery gate: Development
- Risk profile: Standard
- Verification date: 2026-10-05

## CI evidence

GitHub Actions run: `37310658218`

Environment reported by the run:

- Xcode 16.4
- Xcode build 16F6
- Apple Swift 6.1.2

Results:

| Check | Status | Evidence |
| --- | --- | --- |
| iOS app compile against iPhone Simulator SDK | PASS | `** BUILD SUCCEEDED **` |
| Pure production-core tests | PASS | 50 tests, 0 failures |
| Unsigned `iphoneos` device-target compile | PASS | `** BUILD SUCCEEDED **` with `CODE_SIGNING_ALLOWED=NO` |
| App signing / physical-device install | NOT RUN | Requires local signing and physical device |
| Live camera OCR on physical iPhone | NOT RUN | Requires real device |
| Runtime comparison-zone alignment | NOT RUN | Requires real camera view |
| Performance target on iPhone 12-class device | NOT RUN | Requires physical device |
| Public release gate | NOT RUN | Release not authorized |

## Warning review

The successful CI log contains no warning indicating a defect in Price Lens source.

Observed non-blocking environment/tooling warning:

1. Xcode AppIntents metadata processor skipped extraction because the app has no AppIntents framework dependency.

This does not change the result of either build or the 50 core tests.

## Scope proven by this evidence

This evidence supports:

- source compiles as an iOS app;
- production parsing/comparison core passes its automated regression suite;
- project configuration is sufficient for unsigned simulator and unsigned `iphoneos` device-target builds;
- current deterministic parser and comparison behavior is internally verified.

It does **not** support a claim that live OCR is accurate in real stores or that the build is ready for public release.

## Next evidence required

Physical iPhone validation against `docs/VALIDATION.md`.

The next milestone can be called a Validation Build only after the applicable pre-handoff checks are completed and the exact build identity is recorded.
