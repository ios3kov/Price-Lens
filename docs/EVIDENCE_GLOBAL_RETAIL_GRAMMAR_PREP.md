# Global Retail Grammar Validation Preparation Evidence

## Identity

- Product: Price Lens
- Implementation commit: `9e933b6d3b2b1ec5d0b424a4eee1339174d0dff7`
- Branch: `feat/global-retail-grammar`
- Base physical-candidate lineage: `646e6faf76d8bcad4a7a6d5fb9072ac1e55e3098`
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Delivery gate: Validation
- Risk profile: Standard
- Verification date: 2026-10-05

## Goal

Broaden Price Lens from country/retailer-specific price patches to a semantic retail grammar that can handle materially different world price-label conventions without guessing ambiguous labels.

## Research basis

The implementation follows current Apple Foundation locale data and Unicode CLDR number/currency conventions:

- ISO currency inventory from `Locale.Currency.isoCurrencies`;
- localized currency symbols from system locale data;
- CLDR-style symbol/code placement, localized digits and grouping;
- one/two fractional digits plus known three-fraction retail currencies;
- safe preservation of ambiguous shared symbols rather than guessing a country.

Research notes and source URLs are recorded in `docs/RESEARCH.md`.

## Implementation

The branch adds:

- system-derived world currency-symbol inventory with token boundaries;
- protection against one-letter currency symbols colliding with units such as `g` and `L`;
- explicit high-value retail aliases/symbols for additional regions;
- one-, two- and selected three-fraction price forms;
- Scandinavian zero-cents `10:-`;
- bidi isolate normalization;
- metric micro-units plus US/imperial fluid ounce, pint, quart and gallon;
- GBP-context imperial interpretation for bare customary volume units;
- broader count aliases;
- generalized reference-unit-price rejection across supported mass/volume units;
- generic per-selling-unit suffix handling such as `/ea`;
- cached currency/unit regex inventories for live-camera parsing.

## Regression incident and closure

Initial CI run `37368908320` failed because the system locale catalog contains legitimate one-letter alphabetic currency symbols. Raw OCR then misclassified quantity units such as `g` and `L` as currencies.

The fix:

1. excludes inferred one-letter alphabetic symbols from the global locale catalog;
2. allows important one-letter retail symbols only explicitly;
3. applies token-boundary matching to explicit symbols.

This restored the pre-existing safety corpus rather than weakening assertions.

## Fresh CI

GitHub Actions run: `37369541422`

| Check | Status |
| --- | --- |
| iOS Simulator build | PASS |
| unsigned `iphoneos` build | PASS |
| bundle identity | PASS — `com.os3kov.PriceLens 0.1.0 (1)` |
| privacy manifest / Required Reason API | PASS |
| core regression suite | PASS — 101 tests, 0 failures |

New coverage includes:

- one-fraction decimal price;
- KWD three-fraction price;
- Scandinavian `10:-`;
- Bangladeshi taka symbol;
- South African rand system-locale form;
- reference price per pound rejection;
- package `/ea` semantics;
- US pint normalization;
- GBP imperial pint normalization.

## Gate status

- Implementation: PASS
- Automated regression: PASS
- Simulator/device-target build: PASS
- Physical iPhone OCR validation: NOT_RUN
- Merge into `feat/initial-mvp`: NOT_AUTHORIZED / NOT_PERFORMED
- Public release: NOT_AUTHORIZED / NOT_PERFORMED

This evidence proves the parser/build regression gate for the branch. It does not prove recognition of every future shelf label or physical-camera behavior.
