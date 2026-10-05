# Price Lens

**Price Lens** is an iPhone app that compares products by their real unit price using only the camera.

Point the camera at two price tags. The app recognizes price and package size, normalizes them to kg / L / item, and shows which option is actually cheaper.

## Product principle

**No manual entry. Camera only.**

## Development status

The initial native iOS MVP is implemented on `feat/initial-mvp`.

Current AS 4.1 validation candidate: `a2d9d9e0`

- iOS Simulator build: PASS
- Unsigned iPhone device-target build: PASS
- Core tests: 65 / 65 PASS
- Device bundle identity + privacy manifest CI check: PASS
- Previous physical candidate `8450963d`: launched, first-use UX FAIL
- Current UI-fix physical retest: NOT RUN
- Public release: not authorized / not performed

Controlled camera fixtures are in `validation/price-tag-fixtures.html`.

See `docs/PRODUCT_SPEC.md`, `docs/TECHNICAL_DESIGN.md`, `docs/PRIVACY.md`, `docs/ACCESSIBILITY.md`, `docs/VALIDATION.md`, `docs/IPHONE_VALIDATION.md`, `docs/BUILD_IDENTITY_VALIDATION.md`, `docs/DEVICE_QA.md`, `docs/LOCAL_IPHONE_VALIDATION_PACKAGE.md` and `docs/EVIDENCE_AS_4_1_VALIDATION_PREP.md`.
