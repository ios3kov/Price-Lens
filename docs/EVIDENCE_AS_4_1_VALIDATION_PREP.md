# AS 4.1 Validation Preparation Evidence

## Identity

- Product: Price Lens
- Candidate source commit: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06`
- Branch at verification: `feat/initial-mvp`
- Bundle ID: `com.os3kov.PriceLens`
- Marketing version: `0.1.0`
- Build number: `1`
- Standard: AS Development Rules 4.1.0
- Standard commit: `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Risk profile: Standard
- Delivery gate: Validation
- Verification date: 2026-10-05

Applicable modules:

- iOS
- Privacy / Permissions
- Accessibility
- Validation / Release

Not in current product scope:

- Backend
- StoreKit / purchases
- UGC / AI / Kids
- Hybrid
- Games

## Targeted engineering research

Current Apple primary sources were rechecked before the AS 4.1 adoption change. Full URLs and rationale are recorded in `docs/RESEARCH.md`.

Relevant conclusions:

- DataScanner remains supported only on devices meeting its hardware requirement; A12+ remains the declared core-device boundary.
- `.accurate` remains appropriate for smaller text, with speed to be measured on device.
- camera access requires the existing `NSCameraUsageDescription`.
- `ProcessInfo.systemUptime` is a Required Reason API in the System Boot Time category.
- Price Lens' use is elapsed-time measurement between in-app events, matching reason `35F9.1`.
- a bundled privacy manifest is therefore required for this implementation.

Research does not substitute for build or device tests.

## CI Evidence

GitHub Actions run: `37316764549`
Job: `111785342107`

Environment:

- Xcode 16.4
- Apple Swift 6.1.2

Results:

| Check | Status | Evidence |
| --- | --- | --- |
| iOS Simulator compile | PASS | workflow build step completed |
| Unsigned `iphoneos` compile | PASS | workflow device build completed |
| Built bundle identity | PASS | `com.os3kov.PriceLens 0.1.0 (1)` |
| `PrivacyInfo.xcprivacy` bundled | PASS | file exists in built device `.app`, `plutil -lint` PASS |
| Required Reason API category | PASS | `NSPrivacyAccessedAPICategorySystemBootTime` |
| Required Reason API reason | PASS | `35F9.1` |
| Tracking declaration | PASS | false |
| Core regression suite | PASS | 65 tests, 0 failures |
| Signed physical-device install | NOT_RUN | requires local signing + physical iPhone |
| Live camera OCR / A-B overlay | NOT_RUN | physical iPhone required |
| Accessibility runtime checks | NOT_RUN | physical iPhone required |
| Performance <= 1.5 s | NOT_RUN | physical iPhone timing required |

## Privacy scope

Current source architecture declares:

- no account/backend;
- no analytics/ads/tracking SDK;
- no third-party runtime SDK;
- no remote OCR;
- no app-owned camera-frame/photo persistence.

`ProcessInfo.systemUptime` is used only for recognition stabilization and is not persisted or transmitted.

This source/config inventory is not a packet capture. Physical Validation still needs to watch for unexpected runtime behavior; Release later needs current App Store privacy labels, policy/support URLs, Xcode privacy report and exact archive inspection.

## Accessibility scope

Implemented before Validation:

- result accessibility label identifies the winner;
- result accessibility value exposes normalized A/B unit prices;
- winner is not color-only;
- candidate overlay is non-actionable and hidden from VoiceOver;
- candidate-frame animation is disabled with Reduce Motion;
- recovery states use labeled buttons.

Physical VoiceOver / Larger Text / Reduce Motion / contrast checks remain NOT_RUN.

## Warning review

Only observed source-adjacent Xcode warning:

- AppIntents metadata extraction skipped because AppIntents.framework is not linked.

This is expected for the current app and did not affect build/test/privacy verification.

## Scope proven

This Evidence supports that candidate source `8450963d`:

- compiles for simulator and unsigned physical-device target;
- contains the required privacy manifest in the built app;
- has the expected bundle/version/build identity in CI;
- passes the current 65-test core suite;
- is ready to proceed to local signed physical-iPhone Validation.

It does **not** prove:

- successful signed install;
- physical camera behavior;
- overlay alignment;
- real shelf OCR accuracy;
- physical accessibility;
- performance target;
- App Store Release readiness or submission.

Historical Evidence remains immutable in `docs/EVIDENCE_INITIAL_MVP.md`.
