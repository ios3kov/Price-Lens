# Development Status

## Current goal

First end-to-end Price Lens iPhone MVP:

camera -> scan one price label -> review recognized values -> Add -> repeat for 2+ products -> ranked unit-price comparison.

## State

- Repository: ios3kov/Price-Lens
- Working branch: feat/initial-mvp
- Historical physical candidate: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06` — UX FAIL
- Last physically launched candidate: `a2d9d9e0f6c2536335f19deecd7b12b9d4c98013` — workflow UX FAIL
- Last physically launched multi-item candidate: `d33616b9ae39ecae6ffc3054e8ade20afe7745cf` — OCR/parser FAIL on Russian shelf label
- Last physically launched OCR candidate: `7a25dbceb00926a868c5686934c3059e0269e932` — OCR text visible, parser still FAIL on `56 + 99 р/шт. / 315г`
- Last physically launched retail-grammar candidate: `d76107bb1389a215eddba03d2bbdbd8efea9c9bf` — OCR visible, candidate assembly FAIL
- Current physical OCR retest candidate: `114f31f616c1c7cd1c59aee264c916a2867d0b38`
- Standard baseline: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Previous baseline: AE Development Rules 8.0.0 @ `132b7cd32873ba7328e3128ffbb33e1929b74d45` (historical only)
- Delivery gate: Validation
- Risk profile: Standard
- Applicable modules: iOS; Privacy/Permissions; Accessibility; Validation/Release
- Out of current scope: Backend; StoreKit; UGC/AI/Kids; Hybrid; Games
- Product Discovery: complete for initial v1 scope
- Reference Audit: not triggered; no concrete external product is a parity target
- Merge / Release: not authorized and not performed

## Implemented

- Native Swift / SwiftUI iPhone app, iOS 17+.
- VisionKit DataScanner live OCR with `.accurate` quality and A12+ capability requirement.
- Camera permission flow with Settings recovery and transient-failure retry.
- One-label region of interest for deliberate sequential capture.
- Stable candidate preview shows recognized price, normalized quantity and unit price before Add.
- Explicit Add action; recognition alone never mutates the comparison set.
- In-memory ComparisonSession supports 2, 3, 4+ compatible products with no fixed two-item UI limit.
- Horizontal comparison tray keeps added items visible and individually removable; Clear resets the set.
- Lowest normalized unit price is marked BEST and recomputes when items are added or removed.
- Semantic duplicate, mixed-dimension and explicit different-currency additions are rejected.
- Added comparison items survive ordinary background/foreground while the current camera preview resets.
- Existing parser coverage remains: decimal/grouped/split/missing-separator prices, mass/volume/count/multipacks and unit-price traps.
- On-device processing; no backend, analytics, remote OCR or image upload.
- `PrivacyInfo.xcprivacy` declares System Boot Time Required Reason API `35F9.1`.
- Add/remove/clear controls preserve accessibility semantics; candidate-frame animation respects Reduce Motion.
- Controlled multi-item physical fixtures are included at `validation/multi-item-fixtures.html`.

## Internal verification

For current physical OCR retest candidate `114f31f6`:

- GitHub Actions run: `37361384799`
- Xcode 16.4
- Swift 6.1.2
- iOS Simulator build: PASS
- unsigned iPhone device-target build: PASS
- built bundle identity: PASS — `com.os3kov.PriceLens 0.1.0 (1)`
- bundled privacy manifest / Required Reason API `35F9.1`: PASS
- core regression suite: PASS — 92 executed, 0 failures
- generalized retail grammar corpus: PASS
- disconnected OCR fragments inside one-label ROI fallback: PASS
- separate currency suffix fragment `р/шт.`: PASS
- two complete neighboring labels are not collapsed by fallback: PASS
- physical same-label retest: NOT_RUN

Historical Evidence for earlier candidates remains unchanged.

## Current physical-validation findings

Historical candidate `8450963d`:

- local signed install / launch: PASS;
- live scanner opened: PASS;
- first-use camera UX clarity: FAIL.

Replacement candidate `a2d9d9e0`:

- local signed install / launch: PASS;
- camera-first visual cleanup improved the screen;
- core workflow comprehension: FAIL;
- user explicitly reported that it is still unclear what to do and asked how to compare more than two products.

This second result changes the product workflow, not just presentation. The simultaneous-two-label model is retired. The new workflow is sequential deliberate capture: **scan one → preview → Add → scan next**, with an in-memory multi-item comparison tray.

## Latest physical OCR finding

Candidate `d33616b9` launched successfully on the physical iPhone, but the real Russian shelf label in the validation screenshot never reached a parsed candidate.

Observed source format included:

- `229` + `99₽` as the current prominent price;
- smaller `269` + `99` old price;
- `200Г` package quantity;
- Cyrillic promotional/discount text.

Root-cause review found that the parser did not support RUB/₽ at all, so common OCR output such as `99₽` could not participate in split-price reconstruction. DataScanner also had no explicit Russian language priority.

The next candidate adds RUB parsing, dynamic preferred/ru/en language hints and a `Text found` diagnostic state.

## Remaining blocker

The disconnected-OCR recovery path is **not yet validated on a physical iPhone**.

Next required step: build and install exact candidate `114f31f6`; retest the same `56 + 99 р/шт. / 315г` label first. If parsing still fails, the `Text found` card now exposes the exact VisionKit OCR strings in the screenshot.

Blocking runtime failures include any false winner, wrong unit normalization, cross-tag pairing, A/B mismatch, stale result, inaccessible critical recovery/result state, unexpected data flow, or unrecoverable camera state.

## AS 4.1 SCOPE / COMPLETE — current requirement / task / check mapping

This is the current scoped reconciliation for the first iPhone validation milestone.

| Requirement / obligation | Implementation block | Observable acceptance | Check / phase | Current status / Evidence |
| --- | --- | --- | --- | --- |
| Camera-only primary workflow; no manual entry | VisionKit scanner + SwiftUI camera UI | User can compare without typing | pre-handoff: source/build review; user-validation: live camera | Implementation PASS; runtime NOT RUN |
| Multi-item comparison session | single-label capture + ComparisonSession | user can add 2, 3, 4+ compatible products; best unit price updates across the full set | pre-handoff: core tests + physical validation | IMPLEMENTATION PASS; 92-test CI PASS; device NOT_RUN |
| Price + quantity stay associated with the same tag | geometry clustering + recursive split guards | no cross-tag price/quantity pairing | pre-handoff tests + user-validation fixtures | Automated PASS; live camera NOT RUN |
| Unit normalization is correct | Decimal parser / ComparisonEngine | g↔kg, ml/cl↔L, count and multipacks yield correct unit price | pre-handoff: unit tests | PASS |
| Ambiguous/unit-price text does not create a false winner | parser rejection rules | `/kg`, `per 100 g/ml`, unsupported ambiguity do not become package price | pre-handoff: regression tests | PASS |
| Camera lifecycle recovers safely | permission recovery, Try Again, background reset | no stale result after background; denied permission can recover | pre-handoff: compile/review; user-validation: real device | Implementation PASS; runtime NOT RUN |
| Candidate preview corresponds to centered label | DataScanner bounds + one-label ROI | preview outline/value belongs to the label the user is about to add | user-validation: physical iPhone | NOT RUN |
| Live OCR is useful on real shelf labels | DataScanner `.accurate` + one-label ROI + stabilization | stable preview is correct before Add; previously added items remain intact | user-validation: physical iPhone | NOT RUN |
| Performance target | stabilization / on-device processing | useful result <= 1.5 s after stable readable framing | user-validation: physical iPhone timing | NOT RUN |
| Privacy Required Reason API | bundled PrivacyInfo + CI bundle inspection | exact System Boot Time reason 35F9.1 exists in built app | pre-handoff | PASS on 114f31f6 |
| Basic accessibility | SwiftUI semantics + Reduce Motion + result accessibility value | critical result/recovery state is understandable without color-only cues | pre-handoff compile/review + user-validation device checks | Implementation PASS; device checks NOT_RUN |
| Artifact identity for validation | exact Git commit + bundle ID/version/build + local signed Xcode install | installed test build is traceable to exact candidate | pre-handoff/user-validation boundary | unsigned identity PASS; signed installed identity NOT_RUN |
| Merge / public release | explicit user authorization required | no merge/publication without command | permission boundary | NOT AUTHORIZED / NOT PERFORMED |

### Reconciliation result

- Product workflow remains sequential multi-item capture.
- AS Development Rules 4.1.0 remains adopted.
- Parser architecture is now grammar-based rather than retailer/country-template-based.
- `RetailLexicon` centralizes Unicode normalization, ISO currency inventory, symbols/aliases and unit aliases.
- `PriceTagParser` handles structural numeric classes, OCR fragment geometry and ambiguity rejection.
- Unicode CLDR number/currency formatting classes are recorded in `docs/RESEARCH.md`.
- Current candidate `d76107bb` has fresh simulator/device-target/identity/privacy and 89-test PASS evidence.
- Physical generalized-parser retest and M01–M15 remain NOT_RUN.
- App Store Release scope remains separate and unauthorized.
- Current claim: **generalized retail grammar is internally verified; physical retest of previously failing labels is the next gate.**

## Release-only open scope

These items do **not** block the current local iPhone Validation gate, but they remain open for a future App Store Release:

- app icon / asset catalog and final launch presentation;
- final App Store screenshots, description, age rating and review notes;
- support URL and privacy-policy URL;
- final App Store privacy labels and Xcode privacy report from the exact release archive;
- Release archive/export identity, symbols and signing/provisioning review;
- minimum/stable OS compatibility matrix required for the declared Release support;
- final physical accessibility/localization pass for declared languages;
- current Apple submission / SDK / account / agreements / export-compliance checks;
- App Store upload, review and publication — not authorized.

None of these may be retroactively marked PASS from the current Validation evidence.


## Feature-set change — multi-item comparison

Source: user physical-device feedback in the active validation session.

### Retained

- camera-only price/quantity recognition;
- no manual price/quantity entry;
- deterministic unit normalization;
- no guessed winner on ambiguous OCR;
- on-device processing/privacy contract;
- existing parser format support;
- camera permission/recovery;
- AS Development Rules 4.1.0 baseline.

### Changed

- old core workflow: hold exactly two labels in frame simultaneously;
- new core workflow: scan one label, verify parsed values, tap Add, repeat;
- comparison set now supports 2+ compatible products instead of a fixed pair;
- result is the best normalized unit price across the whole set.

### Added

- explicit Add action;
- scrollable comparison tray;
- remove individual item / clear comparison;
- duplicate rejection;
- multi-item ranking;
- explicit incompatible-unit/currency rejection before Add.

### Deferred / not implied

- product names/barcodes;
- persistent history;
- accounts/cloud sync;
- manual corrections;
- App Store release.

Fresh tests and physical-device evidence are required because the workflow and production bytes change.


## OCR-fix scope — Russian shelf label

Retained:

- sequential multi-item workflow;
- explicit Add;
- ComparisonSession;
- parser safety / no guessed winner;
- privacy/accessibility contract.

Changed:

- currency support adds `₽`, `RUB`, `РУБ`;
- scanner text language priorities are selected from actual supported languages, using user preferences plus Russian/English hints;
- scan state distinguishes no text from unparsed text.

Acceptance:

- synthetic reproduction `229 + 99₽` with old `269 + 99`, `-15%` and `200Г` parses current price as `229.99 ₽` and quantity as 0.2 kg;
- `₽` and `RUB` compare as the same currency;
- physical retest of the same Russian label reaches `Label ready` or, if not, at least exposes `Text found` so the next failure is observable rather than silent.


## Retail grammar architecture

The parser no longer treats each retailer/country label as a special case.

Pipeline:

1. Unicode/OCR normalization.
2. Currency/unit lexicon lookup.
3. Structural number parsing.
4. Role classification: package price / old price / reference unit price / quantity / noise.
5. OCR geometry + prominence scoring.
6. Ambiguity gate.
7. ProductCandidate or safe refusal.

Contract: `docs/RETAIL_GRAMMAR.md`.

Current automated corpus includes:

- comma/dot decimals;
- zero-cents notation;
- spaces/NBSP/apostrophe/Indian grouping;
- Arabic-Indic digits and Arabic decimal/group separators;
- currency before/after/in decimal position;
- ISO codes and common world symbols;
- RUB `₽ / RUB / РУБ / р/шт.`;
- metric + lb/oz + dL/cL + count aliases;
- Chinese/Arabic unit aliases;
- Unicode multipacks;
- old/promotional price competition;
- near-tied ambiguity rejection.


## Disconnected OCR recovery

Physical evidence on `d76107bb` showed `Text found` without a candidate even though the generalized grammar included the visible retail format.

The new extraction layer now:

1. parses normal geometry clusters first;
2. if no complete candidate exists, attempts the full single-label ROI as one aggregate label;
3. preserves the parser ambiguity gate, so aggregate fallback cannot bypass safe-refusal logic;
4. allows split whole/cents prices to inherit currency from a separate nearby OCR fragment;
5. exposes up to eight transient OCR lines in `Text found` for physical diagnosis.

No OCR text is persisted or transmitted.
