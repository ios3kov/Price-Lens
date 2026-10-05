# Local iPhone Validation Package — Price Lens

## Exact candidate

- Source commit to build: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06`
- Bundle ID: `com.os3kov.PriceLens`
- Version/build: `0.1.0 (1)`
- Channel: local Xcode signed install
- Standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

Do not build the validation app from a different production-source commit and call it the same candidate.

## Local preparation

From the existing local repository or a clean clone:

```bash
git fetch origin
git checkout 8450963dc1db139d2bed9e1b3fea3e0a3236ae06
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
5. Record device model, iOS version, local Xcode version and installed app version/build in `docs/BUILD_IDENTITY_VALIDATION.md`.

Changing Team for local signing is an environment/signing input; do not commit account-specific team IDs unless deliberately making that a project setting.

## Test data

Start with controlled fixtures:

`validation/price-tag-fixtures.html`

Open it on the Mac, maximize the window and keep only the intended labels inside the dashed Price Lens comparison frame.

Then run real shelf-label scenarios from `docs/DEVICE_QA.md`.

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
