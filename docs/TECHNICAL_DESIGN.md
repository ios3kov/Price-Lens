# Technical Design — Price Lens

## Baseline

Engineering process baseline:

- AS Development Rules 4.1.0
- rules commit: 6a19ab6d44b34376edccda3515f1355d0ead2041
- delivery gate: Validation preparation
- risk profile: Standard
- applicable modules: iOS, Privacy/Permissions, Accessibility, Validation/Release
- not applicable in current scope: Backend, StoreKit, UGC/AI/Kids, Hybrid, Games

The previous AE Development Rules 8.0.0 baseline is historical. AS 4.1.0 is the adopted App Store baseline for current work.

## Architecture

The app is split into four boundaries:

1. **Camera/OCR adapter**
   - VisionKit DataScannerViewController.
   - `.accurate` quality level because shelf-label text is often small; physical-device validation must confirm the speed tradeoff.
   - Live recognized text items.
   - Camera permission / availability handling.
   - A shared ScanRegionLayout defines the visible comparison guide and DataScannerViewController.regionOfInterest in the same view-coordinate system.
   - Text outside that region is excluded before app-owned grouping/parsing.
   - Converts Apple framework objects into app-owned ScannedText values.

2. **Single-label capture + tag grouping**
   - The live region of interest is intentionally sized for one shelf label at a time.
   - Groups nearby recognized text into a candidate shelf label using geometry.
   - If nearby labels collapse into one connected cluster, the fallback tests horizontal and vertical largest-gap splits.
   - A fallback split is accepted only when both halves independently parse as valid price + quantity candidates.
   - If the ROI resolves to more than one valid product candidate, no product is chosen automatically; the user is asked to center one label.
   - Semantic OCR duplicates are collapsed before capture-state decisions.
   - Camera framework types do not leak into parsing logic.

3. **Parsing + comparison-session core**
   - Parses price.
   - Parses package quantity.
   - Normalizes units.
   - Computes unit price.
   - Maintains an in-memory comparison session containing any number of deliberately added compatible products.
   - Rejects semantic duplicates, incompatible dimensions and explicitly different currencies.
   - Ranks the whole session by normalized unit price and exposes the best item.
   - Keeps the existing pairwise ComparisonEngine for pairwise calculations/tests where useful.
   - Pure Swift/Foundation/CoreGraphics only.
   - The exact same source directory is exposed as a Swift Package target for host-independent CI tests; there is no copied test-only implementation.

4. **SwiftUI presentation**
   - Camera-first scanner.
   - One-label scan target.
   - Stable candidate preview that shows recognized price, quantity and unit price.
   - Explicit Add action.
   - Scrollable comparison tray with remove / clear controls and BEST marker.
   - Error/unavailable/incompatible states.

## Why VisionKit DataScanner

Apple provides a live camera scanner that recognizes multiple text items and exposes both transcript and item bounds. It also exposes availability and supported-hardware checks.

This matches the product better than building the first version directly on raw AVCaptureVideoDataOutput + per-frame Vision requests.

The app keeps an adapter boundary so a custom AVFoundation/Vision scanner can replace VisionKit later if profiling shows that we need more control.

## Hardware boundary

DataScanner is supported on A12 Bionic or newer hardware.

Because live scanning is the product’s core feature, the first build treats this as a required device capability instead of shipping a non-functional fallback.

## OCR / comparison-session flow

1. DataScanner recognizes text inside the single-label region of interest.
2. Low-confidence text is filtered.
3. Recognized items are converted into app-owned ScannedText values.
4. TagClusterer groups nearby OCR fragments.
5. PriceTagParser creates zero, one or multiple valid ProductCandidate values.
6. Zero candidates → searching; multiple candidates → ask the user to center one label.
7. One candidate is stabilized for 350 ms.
8. The stable candidate is shown as a preview; recognition alone does not add it.
9. User taps **Add**.
10. ComparisonSession validates duplicate / dimension / currency compatibility and appends the product.
11. Added items remain in memory while the app session is alive.
12. With two or more items, the UI highlights ComparisonSession.bestItem; scanning remains active so more items can be added.

## Stabilization

Live OCR changes constantly. Publishing every frame would make the UI unusable.

Initial strategy:

- Build a semantic signature from normalized price + quantity + dimension for the centered candidate.
- Require the same candidate to remain continuously present for at least 350 ms before enabling Add.
- A changed signature restarts the stabilization timer.
- Losing the centered candidate clears only the current preview; already-added comparison items remain intact.

The 350 ms value is an initial validation parameter and must be tuned on-device if it feels either jumpy or sluggish.

## Parser strategy

Parsing is deterministic and local.

### Price scoring

Price candidates are scored using:

- currency marker present;
- decimal amount with two fraction digits;
- OCR text height / prominence;
- penalties for lines that look like “per kg”, “100 g”, unit price or explanatory text;
- reconstruction of split whole/cents OCR only when the two numeric fragments are horizontally adjacent, vertically aligned and have plausible relative text size.

### Quantity scoring

Quantity candidates are scored using:

- supported unit match;
- multipack match;
- OCR prominence;
- penalties for “per”, slash-unit and unit-price lines.

A bare decimal quantity such as `1.50 L` is not allowed to act as its own price. A single OCR item can supply both price and quantity only when an explicit currency marker disambiguates it.

The parser should return nil rather than choose a weak pair.

## Privacy

Initial version:

- no account;
- no backend;
- no analytics SDK;
- no uploaded frames;
- no photo persistence;
- no remote OCR.

The camera stream stays inside Apple’s local scanning stack and app memory.

The recognition stabilizer uses `ProcessInfo.systemUptime` only to measure elapsed time between in-app OCR events. Apple classifies this as a Required Reason API. The app bundles `PrivacyInfo.xcprivacy` with `NSPrivacyAccessedAPICategorySystemBootTime` / reason `35F9.1`; the value is not persisted or transmitted. See `docs/PRIVACY.md` and `docs/RESEARCH.md`.

## Threading

- VisionKit delegate callbacks are main-actor isolated.
- Parsing/comparison is small and synchronous in the first implementation.
- If profiling shows frame/UI contention, parsing can move to a dedicated task because the app-owned OCR values are value types.

## Test strategy

### Host-independent unit tests

The exact `PriceLens/Core` production sources are compiled as the `PriceLensCore` Swift Package target and tested with `swift test` on the CI host. This keeps pure parsing and comparison tests independent of iOS Simulator availability.

Coverage includes:

- numeric normalization;
- price parser;
- quantity parser;
- multipack parser;
- unit conversion;
- ambiguous same-line OCR;
- neighboring currency marker;
- comparison percentage;
- incompatible dimensions.

### iOS build integration

`xcodebuild` compiles the full iOS app target against the iOS Simulator SDK on every CI run. This verifies that the camera adapter, SwiftUI layer and core compile together.

Simulator/unit tests do not claim real camera semantics.

### Device validation

Required before calling a validation build ready:

- real iPhone;
- supermarket-like shelf labels;
- glare / angled camera;
- small type;
- two tags close together;
- different supported units;
- incompatible units;
- camera permission denied / restored.

## Performance budget

Initial validation target on iPhone 12-class hardware:

- UI stays responsive during scanning.
- No visible camera hitching caused by parsing.
- Stable result appears <= 1.5 s after both valid tags are stably readable.

## Known design risks

1. Shelf labels frequently contain both package price and unit price; prominence and context heuristics must avoid selecting the wrong number.
2. OCR may separate currency and numeric value into different items.
3. Two neighboring labels can be grouped incorrectly.
4. Locale-specific decimal/group separators vary.
5. Package quantity may be absent from the shelf tag and visible only on the product package.

Risk 5 may later require widening the scan target from shelf tags to product packaging or combining shelf + package text. It is not silently assumed solved in v1.


## Multi-item UX decision

Physical validation showed that the simultaneous-two-label model was not self-explanatory and could not scale beyond two products.

The current design therefore uses deliberate sequential capture:

**scan one → verify what was read → Add → scan next**.

Rationale:

- the user always sees the recognized value before it mutates the comparison;
- one-label targeting reduces cross-tag association risk;
- the comparison can grow beyond two items without redesigning the camera state;
- incompatible items can be rejected before they contaminate an existing set;
- a horizontal tray keeps previous choices visible while the camera remains active.

This is a product-workflow change, not merely visual polish. The old two-label candidate remains historical device evidence only.
