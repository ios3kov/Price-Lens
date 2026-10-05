# Multi-item Workflow Validation Preparation Evidence

## Identity

- Product: Price Lens
- Candidate source commit: `d33616b9ae39ecae6ffc3054e8ade20afe7745cf`
- Branch: `feat/initial-mvp`
- Standard: AS Development Rules 4.1.0
- Standard commit: `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Delivery gate: Validation
- Risk profile: Standard
- Verification date: 2026-10-05

## Trigger

Physical iPhone validation rejected the fixed two-label workflow twice:

- `8450963d`: first-use scanner looked/behaved like an engineering prototype.
- `a2d9d9e0`: visual cleanup improved presentation, but the workflow remained unclear and could not answer the user's requirement to compare more than two products.

The fixed `0/2` model is therefore retired.

## Current product workflow

**scan one label → review recognized price/quantity/unit price → Add → scan next**

- recognition alone does not mutate the comparison;
- comparison set supports 2, 3, 4+ compatible products;
- all added products remain in a horizontal tray;
- lowest unit price is marked BEST;
- user can remove one item or clear the set;
- incompatible unit/currency is rejected before addition;
- multiple valid labels inside the one-label ROI do not trigger an automatic choice.

## Targeted research

Current Apple VisionKit/DataScanner and camera-interface guidance was rechecked and recorded in `docs/RESEARCH.md`.

Relevant design facts:

- DataScanner continuously reports recognized content and supports app-owned feedback/actions;
- regionOfInterest can constrain scanning;
- a single shelf label still requires multiple recognized OCR fragments, so `recognizesMultipleItems=true` remains appropriate;
- camera UI should minimize distraction and keep the viewfinder/task clear.

Research does not substitute for runtime tests.

## Fresh CI

GitHub Actions run: `37325029008`

Environment:

- Xcode 16.4
- Apple Swift 6.1.2

Results:

| Check | Status |
| --- | --- |
| iOS Simulator build | PASS |
| unsigned `iphoneos` build | PASS |
| bundle ID / version / build inspection | PASS — `com.os3kov.PriceLens 0.1.0 (1)` |
| bundled privacy manifest | PASS |
| Required Reason API | PASS — System Boot Time / `35F9.1` |
| core regression suite | PASS — 70 tests, 0 failures |
| physical multi-item workflow | NOT_RUN |

Known non-blocking warning remains the AppIntents metadata extraction skip because AppIntents is not linked.

## New core evidence

The pure production core now tests:

- three compatible products retained in one session;
- ranking by normalized unit price;
- BEST item identity;
- duplicate rejection;
- incompatible dimension rejection;
- explicit different-currency rejection;
- remove and clear operations.

Existing parser/comparison regressions remain in the same 70-test run.

## Review

Separate diff/spec review performed after implementation:

- scan state no longer assumes a pair;
- ComparisonSession owns added items independently from current camera recognition;
- ordinary background reset clears only the live preview, not added comparison items;
- Add is an explicit control and is not merged into a single VoiceOver element;
- previous pairwise ComparisonEngine remains available but no longer controls the main workflow.

No new internal blocking finding remains.

## Still NOT_RUN

Physical iPhone M01–M15 scenarios, including:

- first-use comprehension;
- stable preview correctness;
- deliberate Add;
- 2nd/3rd/4th+ item behavior;
- remove / clear;
- incompatible candidate handling;
- background/foreground retention;
- VoiceOver;
- real shelf labels and timing.

Controlled sequential fixtures: `validation/multi-item-fixtures.html`.

Therefore `d33616b9` is ready for physical multi-item validation, not declared Validation-complete.
