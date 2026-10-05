# Generalized Retail Grammar Validation Preparation Evidence

## Identity

- Product: Price Lens
- Candidate source commit: `d76107bb1389a215eddba03d2bbdbd8efea9c9bf`
- Branch: `feat/initial-mvp`
- Standard: AS Development Rules 4.1.0
- Standard commit: `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Delivery gate: Validation
- Risk profile: Standard
- Verification date: 2026-10-05

## Trigger

Repeated physical shelf-label failures showed that country/retailer-specific parser patches would not scale:

- `d33616b9`: Russian `229 + 99₽ / 200Г` produced no candidate.
- `7a25dbce`: VisionKit clearly saw text (`Text found`) on a different Russian label, but `56 + 99 р/шт. / 315г` still did not parse.

This evidence changed the parser architecture from bounded special cases to a reusable retail grammar.

## Architecture

New `RetailLexicon` centralizes:

- Unicode compatibility and digit/separator normalization;
- Foundation ISO currency codes;
- common currency symbols and retail aliases;
- unit aliases with explicit dimension/multiplier;
- package-price suffix normalization;
- reference-unit-price classification.

`PriceTagParser` now applies:

1. normalization;
2. lexicon lookup;
3. structural price/quantity parsing;
4. OCR geometry and prominence;
5. ambiguity gate;
6. ProductCandidate or safe refusal.

Contract: `docs/RETAIL_GRAMMAR.md`.

## External formatting research

Unicode CLDR number/currency formatting classes were used to broaden structural coverage. Research URLs and consequences are recorded in `docs/RESEARCH.md`.

This research does not prove all future price labels can be recognized. The product claim is broad grammar coverage plus safe refusal and a regression process for new classes.

## Fresh CI

GitHub Actions run: `37359173440`

| Check | Status |
| --- | --- |
| iOS Simulator build | PASS |
| unsigned `iphoneos` build | PASS |
| bundle ID/version/build inspection | PASS — `com.os3kov.PriceLens 0.1.0 (1)` |
| bundled privacy manifest | PASS |
| Required Reason API | PASS — System Boot Time / `35F9.1` |
| core regression suite | PASS — 89 tests, 0 failures |
| physical generalized-parser retest | NOT_RUN |

Known non-blocking warning remains AppIntents metadata extraction skipped because AppIntents is not linked.

## Notable automated grammar evidence

The 89-test corpus includes:

- `R$ 12,90`;
- `CHF 1’299.95`;
- `₹1,29,999.00`;
- Arabic-Indic digits / Arabic decimal separator;
- `12€50`;
- Chinese and Arabic unit aliases;
- lb / oz normalization;
- `2×500 мл`;
- Russian `229 + 99₽ / 200Г`;
- Russian `56 + 99 р/шт. / 315г`;
- near-tied promotional-price ambiguity rejection.

## Safety boundary

The parser does not claim to infer shopper eligibility or hidden retail conditions.

When two materially different interpretations are close in score, parsing returns no ProductCandidate. This preserves the product rule: **no guessed winner**.

## Physical next gate

Retest, in this order:

1. original `229 + 99₽ / 200Г` label;
2. `56 + 99 р/шт. / 315г` label that previously reached `Text found`;
3. controlled multi-item fixture;
4. real shelf labels across different layouts.

Candidate `d76107bb` is internally verified and ready for physical retail-grammar validation, not Validation-complete.
