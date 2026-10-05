# Initial MVP Engineering Evidence

## Identity

- Product: Price Lens
- Source commit: `7baf84b6d3a9310cd322559a303e2c1f9afc070b`
- Branch at verification: `feat/initial-mvp`
- Standard baseline: AE Development Rules 8.0.0
- Standard commit: `132b7cd32873ba7328e3128ffbb33e1929b74d45`
- Delivery gate: Development
- Risk profile: Standard
- Verification date: 2026-10-05

## CI evidence

GitHub Actions run: `37313009533`

Environment reported by the run:

- Xcode 16.4
- Xcode build 16F6
- Apple Swift 6.1.2

Results:

| Check | Status | Evidence |
| --- | --- | --- |
| iOS app compile against iPhone Simulator SDK | PASS | `** BUILD SUCCEEDED **` |
| Unsigned `iphoneos` device-target compile | PASS | `** BUILD SUCCEEDED **` with `CODE_SIGNING_ALLOWED=NO` |
| Pure production-core tests | PASS | 65 tests, 0 failures |
| App signing / physical-device install | NOT RUN | Requires local signing and physical device |
| Controlled live-camera fixtures | NOT RUN | Requires physical iPhone |
| Real shelf OCR | NOT RUN | Requires physical iPhone |
| Runtime comparison-zone / A-B alignment | NOT RUN | Requires real camera view |
| Performance target on iPhone 12-class device | NOT RUN | Requires physical device |
| Public release gate | NOT RUN | Release not authorized |

## Regression scope covered

The automated suite verifies, among other cases:

- dot/comma/grouped prices;
- zero-cents and integer-with-currency prices;
- split whole/cents OCR;
- standalone nearby currency fragments;
- missing decimal separator only when currency disambiguates it;
- rejection of quantity-like price traps;
- g/kg, ml/cl/L and count normalization;
- grouped base-unit quantities such as `1.500 g` and `1,500 ml`;
- multipacks including grouped base-unit size;
- package-price vs unit-price discrimination, including `per 100 g/ml`;
- mixed dimensions and different currencies;
- recursive multi-tag clustering;
- deduplication and exact two-candidate selection;
- side-by-side / vertical A-B ordering;
- time-based stabilization and dropout grace behavior;
- comparison-zone geometry.

## Warning review

The successful CI log contains no warning indicating a defect in Price Lens source.

Observed non-blocking environment warning:

1. Xcode AppIntents metadata processor skipped extraction because the app has no AppIntents framework dependency.

This does not change the result of either build or the 65 core tests.

## Source hygiene review

Search at the verified source found no:

- `TODO`;
- `FIXME`;
- `fatalError(`;
- debug `print(`.

## Scope proven by this evidence

This evidence supports:

- source compiles for both iOS Simulator and unsigned physical-device target;
- production parsing/comparison core passes its current automated regression suite;
- deterministic ambiguity guards are internally verified;
- project configuration is sufficient to proceed to signed physical-device validation.

It does **not** support a claim that live OCR is accurate in real stores, that overlays align correctly on a physical device, or that the build is ready for public release.

## Next evidence required

Physical iPhone validation against `docs/IPHONE_VALIDATION.md` and `docs/VALIDATION.md`.

The controlled fixture page is `validation/price-tag-fixtures.html`.
