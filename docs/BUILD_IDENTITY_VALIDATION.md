# Validation Build Identity — Price Lens

Status meanings follow AS Development Rules 4.1.0. This record does not claim a physical-device install until the fields below are filled from the actual run.

## Source / standard

- Candidate source commit: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06`
- Expected dirty state: clean
- Branch context: `feat/initial-mvp`
- Standard: AS Development Rules 4.1.0
- Standard commit: `6a19ab6d44b34376edccda3515f1355d0ead2041`

## App identity

- Bundle ID: `com.os3kov.PriceLens`
- Marketing version: `0.1.0`
- Build number: `1`
- Deployment target: iOS 17.0
- Target device family: iPhone
- Installation channel for this gate: local Xcode signed install
- App Store / TestFlight upload: NOT_AUTHORIZED / NOT_PERFORMED

## CI candidate evidence

- GitHub Actions run: `37316764549`
- Xcode: 16.4
- Swift: 6.1.2
- Simulator build: PASS
- Unsigned `iphoneos` build: PASS
- Device bundle identity inspection: PASS
- Bundled `PrivacyInfo.xcprivacy`: PASS
- Required Reason API: `NSPrivacyAccessedAPICategorySystemBootTime / 35F9.1`: PASS
- Core tests: 65 / 65 PASS

## Local signed build — fill during device run

- Local checkout commit: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06` — USER-REPORTED PASS
- Git dirty state: clean (`git status --short` produced no output) — USER-REPORTED PASS
- Local Xcode version: Xcode 27.0, build 27A266a — USER-REPORTED
- Selected Development Team: NOT_RUN
- Connected device model: NOT_RUN
- iOS version: NOT_RUN
- Signed build success: NOT_RUN
- Installed Bundle ID/version/build observed: NOT_RUN
- Install timestamp UTC: NOT_RUN

If any production source, build setting, privacy manifest or compiled resource changes after candidate `8450963d`, create a new candidate and fresh affected Evidence.
