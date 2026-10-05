# Validation Build Identity — Disconnected OCR Recovery

## Expected candidate

- Source commit: `114f31f616c1c7cd1c59aee264c916a2867d0b38`
- Expected source state: clean except local Development Team signing input and Xcode-generated workspace metadata
- Bundle ID: `com.os3kov.PriceLens`
- Marketing version/build: `0.1.0 (1)`
- Channel: local Xcode signed install
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

## Pre-handoff CI

- GitHub Actions run: `37361384799`
- Xcode 16.4
- Swift 6.1.2
- Simulator build: PASS
- unsigned device-target build: PASS
- bundle identity/privacy manifest: PASS
- core tests: 92 / 92 PASS

New affected regression coverage:

- aggregate fallback across disconnected OCR clusters inside one-label ROI;
- split price with separate whole / cents / currency suffix fragments;
- previously observed `315г + 56 + 99 + р/шт.` form;
- two complete neighboring labels remain separate.

## Local physical install

- Local checkout exact commit: NOT_RUN
- Git dirty state / allowed signing-only diff: NOT_RUN
- Local Xcode version: NOT_RUN
- Development Team/signing result: NOT_RUN
- Device model: NOT_RUN
- iOS version: NOT_RUN
- Install/launch: NOT_RUN
- Installed version/build observed: NOT_RUN
- Timestamp UTC: NOT_RUN
