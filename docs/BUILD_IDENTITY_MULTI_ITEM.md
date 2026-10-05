# Validation Build Identity — Multi-item Workflow

## Expected candidate

- Source commit: `d33616b9ae39ecae6ffc3054e8ade20afe7745cf`
- Expected source state: clean except local Development Team signing input and Xcode-generated workspace metadata
- Bundle ID: `com.os3kov.PriceLens`
- Marketing version/build: `0.1.0 (1)`
- Channel: local Xcode signed install
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

## Pre-handoff CI

- GitHub Actions run: `37325029008`
- Xcode 16.4
- Swift 6.1.2
- Simulator build: PASS
- unsigned device-target build: PASS
- bundle identity: PASS
- bundled privacy manifest / System Boot Time reason `35F9.1`: PASS
- core tests: 70 / 70 PASS

New regression coverage includes:

- 3+ compatible items;
- ranking and BEST selection;
- semantic duplicate rejection;
- mixed-dimension rejection;
- different-currency rejection;
- remove and clear.

## Local physical install

Fill from the new run; no runtime result carries forward from `a2d9d9e0` or `8450963d`.

- Local checkout exact commit: NOT_RUN
- Git dirty state / allowed signing-only diff: NOT_RUN
- Local Xcode version: NOT_RUN
- Development Team/signing result: NOT_RUN
- Device model: NOT_RUN
- iOS version: NOT_RUN
- Install/launch: NOT_RUN
- Installed version/build observed: NOT_RUN
- Timestamp UTC: NOT_RUN

Any production source or build-resource change creates another candidate and requires fresh affected Evidence.
