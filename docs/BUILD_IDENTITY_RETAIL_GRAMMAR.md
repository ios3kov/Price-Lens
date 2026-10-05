# Validation Build Identity — Generalized Retail Grammar

## Expected candidate

- Source commit: `d76107bb1389a215eddba03d2bbdbd8efea9c9bf`
- Expected source state: clean except local Development Team signing input and Xcode-generated workspace metadata
- Bundle ID: `com.os3kov.PriceLens`
- Marketing version/build: `0.1.0 (1)`
- Channel: local Xcode signed install
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

## Pre-handoff CI

- GitHub Actions run: `37359173440`
- Xcode 16.4
- Swift 6.1.2
- Simulator build: PASS
- unsigned device-target build: PASS
- bundle identity/privacy manifest: PASS
- core tests: 89 / 89 PASS

## Grammar classes covered by automated corpus

- dot/comma decimals;
- zero-cents notation;
- space/NBSP/apostrophe grouping;
- Indian grouping;
- Arabic-Indic digits and Arabic separators;
- currency before/after/in decimal position;
- ISO currency codes and common symbols;
- RUB / ₽ / р/шт.;
- metric mass/volume/count aliases;
- lb/oz, dL/cL;
- Chinese/Arabic unit aliases;
- Unicode multipacks;
- old/promotional competing prices;
- ambiguity rejection.

## Local physical install

Fill from the new run; no runtime result carries forward from older candidates.

- Local checkout exact commit: NOT_RUN
- Git dirty state / allowed signing-only diff: NOT_RUN
- Local Xcode version: NOT_RUN
- Development Team/signing result: NOT_RUN
- Device model: NOT_RUN
- iOS version: NOT_RUN
- Install/launch: NOT_RUN
- Installed version/build observed: NOT_RUN
- Timestamp UTC: NOT_RUN
