# Validation Build Identity — Camera UX Retest

## Expected candidate

- Source commit: `a2d9d9e0f6c2536335f19deecd7b12b9d4c98013`
- Expected source state: clean
- Bundle ID: `com.os3kov.PriceLens`
- Marketing version/build: `0.1.0 (1)`
- Channel: local Xcode signed install
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

## Pre-handoff CI

- Run: `37321046482`
- Simulator build: PASS
- unsigned device build: PASS
- bundle identity/privacy manifest: PASS
- tests: 65 / 65 PASS

## Local physical install

Fill from the new run; values do not carry forward from candidate `8450963d`.

- Local checkout exact commit: NOT_RUN
- Git dirty state: NOT_RUN
- Local Xcode version: NOT_RUN
- Development Team/signing result: NOT_RUN
- Device model: NOT_RUN
- iOS version: NOT_RUN
- Install/launch: NOT_RUN
- Installed version/build observed: NOT_RUN
- Timestamp UTC: NOT_RUN

Any production source/build-resource change creates another candidate and invalidates these pending runtime fields.
