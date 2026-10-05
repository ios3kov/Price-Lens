# Disconnected OCR Recovery Validation Preparation Evidence

## Identity

- Product: Price Lens
- Candidate source commit: `114f31f616c1c7cd1c59aee264c916a2867d0b38`
- Branch: `feat/initial-mvp`
- Standard: AS Development Rules 4.1.0
- Delivery gate: Validation
- Risk profile: Standard
- Verification date: 2026-10-05

## Trigger

Physical retest of generalized retail-grammar candidate `d76107bb` still showed `Text found` on the real `56 + 99 р/шт. / 315г` shelf label.

This proves VisionKit recognized text, but the app failed to assemble a ProductCandidate.

The likely structural cause is OCR geometry: package quantity, whole price, cents and currency suffix can arrive as separate disconnected OCR groups even though they belong to one physical label.

## Fix

A new pure `CandidateExtractor` layer now:

1. parses normal geometry clusters first;
2. returns those candidates unchanged when any valid cluster exists;
3. only if no cluster forms a complete product, attempts the entire single-label ROI as one aggregate cluster;
4. keeps PriceTagParser's ambiguity gate active during fallback;
5. allows split whole/cents prices to inherit a nearby standalone currency fragment.

ScannerModel now uses CandidateExtractor rather than invoking TagClusterer + parser directly.

## Physical diagnostics

`Text found` now exposes up to eight transient OCR strings returned by VisionKit.

The strings:

- are shown only while recognition is unresolved;
- are not persisted;
- are not transmitted;
- make a screenshot sufficient to diagnose the next parser/OCR mismatch.

## Fresh CI

GitHub Actions run: `37361384799`

| Check | Status |
| --- | --- |
| iOS Simulator build | PASS |
| unsigned `iphoneos` build | PASS |
| bundle identity | PASS — `com.os3kov.PriceLens 0.1.0 (1)` |
| privacy manifest | PASS |
| Required Reason API | PASS — System Boot Time / `35F9.1` |
| core regression suite | PASS — 92 tests, 0 failures |
| physical same-label retest | NOT_RUN |

Known non-blocking warning remains AppIntents metadata extraction skipped because AppIntents is not linked.

## New core evidence

The 92-test suite now additionally proves:

- disconnected `315г` and `56 / 99 / р/шт.` OCR fragments can recover through the full-ROI fallback;
- separate currency suffix fragments can participate in split-price reconstruction;
- two already-complete neighboring labels are not collapsed by the fallback.

## Safety

Fallback is conditional: it runs only when normal cluster parsing produced zero candidates.

PriceTagParser ambiguity rejection remains active. The fallback therefore does not authorize guessing across equally plausible competing prices.

## Next gate

Retest the exact physical label that previously stayed at `Text found`.

Expected:

- preferred: `Label ready` with 56.99 ₽ and 315 g;
- diagnostic fallback: `Text found` with actual OCR strings visible in the card.

Candidate is ready for physical retest, not Validation-complete.
