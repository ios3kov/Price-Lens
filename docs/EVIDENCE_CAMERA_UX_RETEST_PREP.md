# Camera UX Retest Preparation Evidence

## Candidate

- Source commit: `a2d9d9e0f6c2536335f19deecd7b12b9d4c98013`
- Branch: `feat/initial-mvp`
- Standard: AS Development Rules 4.1.0
- Standard commit: `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Delivery gate: Validation
- Risk: Standard

## Trigger / original symptom

Physical user validation of previous candidate `8450963d` showed the scanner running, but the first screen failed the core UX acceptance:

- large black areas visually dominated the camera;
- dominant dashed ROI looked technical/debug-like;
- guidance panel obscured too much camera content;
- no glanceable 0/2 → 1/2 → 2/2 recognition state;
- first-use hierarchy did not make automatic two-label comparison obvious.

That user-reported physical result remains historical Evidence in `docs/DEVICE_QA.md`.

## Fix scope

Changed presentation/scanner sizing only:

- force camera representable toward full available size;
- minimal four-corner scan guide;
- compact recognition progress;
- compact bottom guidance;
- A/B labels remain anchored to recognized candidates;
- redesigned result comparison sheet;
- one semantic-pair success haptic;
- retained Reduce Motion and VoiceOver support.

OCR parsing/comparison rules were not changed.

## Targeted UX research

Apple primary guidance was rechecked and recorded in `docs/RESEARCH.md`. The relevant design direction is to maximize the viewfinder, minimize distractions and keep state/feedback clear and contextual.

## Fresh CI

GitHub Actions run: `37321046482`

- Xcode 16.4: PASS
- Swift 6.1.2
- iOS Simulator build: PASS
- unsigned `iphoneos` build: PASS
- built bundle identity: PASS — `com.os3kov.PriceLens 0.1.0 (1)`
- bundled privacy manifest / System Boot Time reason `35F9.1`: PASS
- core regression suite: 65 tests, 0 failures

Only the known non-blocking AppIntents metadata-extraction warning remains.

## Still NOT_RUN

Fresh physical iPhone evidence for the new bytes:

- D01 install/launch;
- D28 original first-use UX symptom;
- full-screen camera appearance;
- scan-corner / A-B coordinate alignment;
- 0/2 → 1/2 → 2/2 status behavior;
- result sheet usability;
- success haptic;
- VoiceOver / Larger Text / Reduce Motion;
- controlled fixtures and real shelf labels.

Therefore candidate `a2d9d9e0` is ready for physical retest, not declared Validation-complete.
