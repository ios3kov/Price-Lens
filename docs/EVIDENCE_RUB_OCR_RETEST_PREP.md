# Russian RUB OCR Retest Preparation Evidence

## Identity

- Product: Price Lens
- Candidate source commit: `7a25dbceb00926a868c5686934c3059e0269e932`
- Branch: `feat/initial-mvp`
- Standard: AS Development Rules 4.1.0
- Standard commit: `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Delivery gate: Validation
- Risk profile: Standard
- Verification date: 2026-10-05

## Trigger

Physical validation of multi-item candidate `d33616b9` showed:

- app installed/launched;
- camera and one-label ROI were visible;
- real Russian promotional shelf label never produced a candidate preview or Add action.

Observed label:

- current prominent price: `229` + `99₽`;
- old smaller price: `269` + `99`;
- quantity: `200Г`;
- discount/promotional Cyrillic text.

## Root cause

Source review found two bounded gaps:

1. parser currency support omitted `₽ / RUB / РУБ`, so OCR output such as `99₽` could not participate in split-price reconstruction;
2. DataScanner used the default language configuration only; Apple documents language hints for expected non-default content.

## Fix

- add `₽ / RUB / РУБ` throughout price/currency parsing;
- normalize all three forms to RUB for comparison;
- format ₽ as a currency symbol in UI;
- build DataScanner language hints from actual supported languages, prioritizing the user's preferred languages plus Russian/English when available;
- add `Text found` state to distinguish OCR-visible-but-unparsed text from no OCR text.

## Apple source check

Recorded in `docs/RESEARCH.md`.

Apple documents that:

- `text(languages:textContentType:)` accepts language identifiers as prioritization hints;
- empty language hints use the user's preferred languages;
- the scanner continues to recognize all supported languages;
- `supportedTextRecognitionLanguages` is the source of current supported identifiers.

## Fresh CI

GitHub Actions run: `37355428673`

| Check | Status |
| --- | --- |
| iOS Simulator build | PASS |
| unsigned `iphoneos` build | PASS |
| bundle ID / version / build inspection | PASS — `com.os3kov.PriceLens 0.1.0 (1)` |
| bundled privacy manifest | PASS |
| Required Reason API | PASS — System Boot Time / `35F9.1` |
| core regression suite | PASS — 73 tests, 0 failures |
| physical same-label retest | NOT_RUN |

Known non-blocking warning remains AppIntents metadata extraction skipped because AppIntents is not linked.

## Exact regression

Synthetic OCR geometry reproduces:

- `-15% СКИДКА`;
- product text with `200Г`;
- old `269` + `99`;
- current large `229` + smaller `99₽`.

Expected and observed automated result:

- price = `229.99`;
- currency = `₽`;
- normalized quantity = `0.2 kg`.

This does not prove VisionKit will emit the same transcripts on the physical device; that is the purpose of the retest.

## Physical diagnostic decision tree

On candidate `7a25dbce`:

- **Label ready** → parser/OCR path works; continue Add and multi-item tests.
- **Text found** → VisionKit sees text but parser still lacks the exact OCR form; capture screen and follow with bounded transcript diagnostics.
- **Scan a price label** → DataScanner is not reporting text in the ROI; investigate recognition/language/ROI rather than adding more parser heuristics.

Controlled fixture: `validation/russian-ruble-fixture.html`.

Candidate is ready for same-label physical retest, not Validation-complete.
