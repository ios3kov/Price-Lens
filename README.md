# Price Lens

**Price Lens** is an iPhone app that compares products by their real unit price using only the camera.

Scan one price label, review what Price Lens recognized, tap Add, then scan the next. Add as many compatible products as you need; Price Lens normalizes them to kg / L / item and keeps the best value highlighted.

## Product principle

**No manual entry. Camera only.**

## Development status

The initial native iOS MVP is implemented on `feat/initial-mvp`.

Current AS 4.1 multi-item validation candidate: `d33616b9`

- iOS Simulator build: PASS
- Unsigned iPhone device-target build: PASS
- Core tests: 70 / 70 PASS
- Device bundle identity + privacy manifest CI check: PASS
- Physical candidates `8450963d` and `a2d9d9e0`: launched, workflow UX FAIL
- Multi-item physical retest: NOT RUN
- Public release: not authorized / not performed

Controlled multi-item camera fixtures are in `validation/multi-item-fixtures.html`.

See `docs/PRODUCT_SPEC.md`, `docs/TECHNICAL_DESIGN.md`, `docs/PRIVACY.md`, `docs/ACCESSIBILITY.md`, `docs/DEVICE_QA.md`, `docs/LOCAL_IPHONE_VALIDATION_PACKAGE.md`, `docs/BUILD_IDENTITY_MULTI_ITEM.md` and `docs/EVIDENCE_MULTI_ITEM_VALIDATION_PREP.md`.
