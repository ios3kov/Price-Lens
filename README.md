# Price Lens

**Price Lens** is an iPhone app that compares products by their real unit price using only the camera.

Point the camera at two price tags. The app recognizes price and package size, normalizes them to kg / L / item, and shows which option is actually cheaper.

## Product principle

**No manual entry. Camera only.**

## Development status

The initial native iOS MVP is implemented on `feat/initial-mvp`.

Current internally verified source: `7baf84b6`

- iOS Simulator build: PASS
- Unsigned iPhone device-target build: PASS
- Core tests: 65 / 65 PASS
- Live physical-iPhone camera validation: NOT RUN
- Public release: not authorized / not performed

Controlled camera fixtures are in `validation/price-tag-fixtures.html`.

See `docs/PRODUCT_SPEC.md`, `docs/TECHNICAL_DESIGN.md`, `docs/VALIDATION.md`, `docs/IPHONE_VALIDATION.md` and `docs/EVIDENCE_INITIAL_MVP.md`.
