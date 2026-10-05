# Initial MVP Engineering Evidence

## Identity

- Product: Price Lens
- Source commit: `61653ae94b15c4c2e29c3e24207f1097ffe10746`
- Branch at verification: `feat/initial-mvp`
- Standard baseline: AE Development Rules 8.0.0
- Standard commit: `132b7cd32873ba7328e3128ffbb33e1929b74d45`
- Delivery gate: Development
- Risk profile: Standard
- Verification date: 2026-10-05

## CI evidence

GitHub Actions run: `37307272302`

Environment reported by the run:

- Xcode 16.4
- Xcode build 16F6
- Apple Swift 6.1.2

Results:

| Check | Status | Evidence |
| --- | --- | --- |
| iOS app compile against iPhone Simulator SDK | PASS | `** BUILD SUCCEEDED **` |
| Pure production-core tests | PASS | 33 tests, 0 failures |
| App signing / physical-device install | NOT RUN | Development CI intentionally uses `CODE_SIGNING_ALLOWED=NO` |
| Live camera OCR on physical iPhone | NOT RUN | Requires real device |
| Runtime comparison-zone alignment | NOT RUN | Requires real camera view |
| Performance target on iPhone 12-class device | NOT RUN | Requires physical device |
| Public release gate | NOT RUN | Release not authorized |

## Warning review

The successful CI log contains no warning indicating a defect in Price Lens source.

Observed non-blocking environment/tooling warnings:

1. Xcode AppIntents metadata processor skipped extraction because the app has no AppIntents framework dependency.
2. GitHub Actions reports that `actions/checkout@v4` targets deprecated Node.js 20 and is being forced to Node.js 24 by the runner.

Neither changes the result of the app compile or the 33 core tests.

## Scope proven by this evidence

This evidence supports:

- source compiles as an iOS app;
- production parsing/comparison core passes its automated regression suite;
- project configuration is sufficient for unsigned simulator build;
- current deterministic parser and comparison behavior is internally verified.

It does **not** support a claim that live OCR is accurate in real stores or that the build is ready for public release.

## Next evidence required

Physical iPhone validation against `docs/VALIDATION.md`.

The next milestone can be called a Validation Build only after the applicable pre-handoff checks are completed and the exact build identity is recorded.
