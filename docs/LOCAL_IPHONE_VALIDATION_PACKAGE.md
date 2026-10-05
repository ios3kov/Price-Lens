# Local iPhone Validation Package — Price Lens

## Exact candidate

- Source commit to build: `114f31f616c1c7cd1c59aee264c916a2867d0b38`
- Bundle ID: `com.os3kov.PriceLens`
- Version/build: `0.1.0 (1)`
- Channel: local Xcode signed install
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

This candidate adds disconnected-OCR recovery and transient OCR-line diagnostics after the generalized parser still reached `Text found` on a physical Russian shelf label. Do not build from a different production-source commit and call it the same candidate.

## Local preparation

From the existing local repository or a clean clone:

```bash
git fetch origin
git checkout 114f31f616c1c7cd1c59aee264c916a2867d0b38
git status --short
git rev-parse HEAD
xcodebuild -version
```

Acceptance before opening Xcode:

- `git rev-parse HEAD` prints the exact candidate above;
- `git status --short` is empty.

Open `PriceLens.xcodeproj`.

In Xcode:

1. Select target `PriceLens`.
2. Signing & Capabilities: select the available Development Team if Xcode requires it.
3. Select the connected physical iPhone as Run destination.
4. Run the `PriceLens` scheme.
5. Record device model, iOS version, local Xcode version and installed app version/build in `docs/BUILD_IDENTITY_MULTI_ITEM.md`.

Changing Team for local signing is an environment/signing input; do not commit account-specific team IDs unless deliberately making that a project setting.

## Test data

First retest both previously failing Russian label classes:

1. the original physical `229 + 99₽ / 200Г` label (or `validation/russian-ruble-fixture.html`);
2. the physical `56 + 99 р/шт. / 315г` label from the second OCR screenshot.

Then continue with the controlled grammar / multi-item corpus.

Controlled RUB fixture:

`validation/russian-ruble-fixture.html`

Expected: `Label ready` with 229.99 ₽, 200 g and a unit price near 1149.95 ₽/kg.

If the app instead shows `Text found`, capture that screen: VisionKit is reading text but the parser still needs the exact OCR transcript. If it stays at `Scan a price label`, the remaining issue is OCR/language recognition rather than parsing.

Then continue with the sequential controlled fixture:

`validation/multi-item-fixtures.html`

Open it on the Mac and scan only the single label currently displayed.

Required first pass:

1. Case 1 → stable preview → Add.
2. Case 2 → Add → Item 2 becomes BEST.
3. Case 3 → Add → all three remain; Item 2 remains BEST.
4. Case 4 → Add → tray remains usable with four items.
5. Case 5 → volume item is rejected from the kg comparison and the existing BEST does not change.
6. Test remove, Clear/Start new, then continue scanning.

Then run the M01–M15 real-device scenarios from `docs/DEVICE_QA.md` and finally real shelf labels.

## Evidence capture

For each failure capture, when useful:

- scenario ID;
- candidate commit;
- device / iOS;
- timestamp;
- screenshot or short screen/camera video;
- expected result;
- actual result;
- whether issue reproduces.

Do not include Apple account credentials, signing keys, real personal data or unrelated screen content in shared Evidence.

## Feedback / next action

Record results in `docs/DEVICE_QA.md` or provide them back in chat. Runtime observations remain NOT_RUN until actually observed.

If any production source change is required, the old installed build is historical Evidence only: create a new source candidate, run affected CI again, reinstall the new candidate and repeat impacted device scenarios.
