# Technical Design — Price Lens

## Baseline

Engineering process baseline:

- AE Development Rules 8.0.0
- rules commit: 132b7cd32873ba7328e3128ffbb33e1929b74d45
- delivery gate: Development
- risk profile for initial implementation: Standard

The rules are used as a general engineering standard; After Effects-specific runtime requirements are not applicable to this iOS app.

## Architecture

The app is split into four boundaries:

1. **Camera/OCR adapter**
   - VisionKit DataScannerViewController.
   - Live recognized text items.
   - Camera permission / availability handling.
   - Converts Apple framework objects into app-owned ScannedText values.

2. **Tag grouping**
   - Groups nearby recognized text into candidate shelf labels using geometry.
   - If nearby labels collapse into one connected cluster, the fallback tests both horizontal and vertical largest-gap splits.
   - A fallback split is accepted only when both halves independently parse as valid price + quantity candidates.
   - Camera framework types do not leak into parsing logic.

3. **Parsing + comparison core**
   - Parses price.
   - Parses package quantity.
   - Normalizes units.
   - Computes unit price.
   - Decides winner and percentage.
   - Pure Swift/Foundation/CoreGraphics only.
   - The exact same source directory is exposed as a Swift Package target for host-independent CI tests; there is no copied test-only implementation.

4. **SwiftUI presentation**
   - Full-screen scanner.
   - Minimal guidance.
   - Result card.
   - Error/unavailable states.

## Why VisionKit DataScanner

Apple provides a live camera scanner that recognizes multiple text items and exposes both transcript and item bounds. It also exposes availability and supported-hardware checks.

This matches the product better than building the first version directly on raw AVCaptureVideoDataOutput + per-frame Vision requests.

The app keeps an adapter boundary so a custom AVFoundation/Vision scanner can replace VisionKit later if profiling shows that we need more control.

## Hardware boundary

DataScanner is supported on A12 Bionic or newer hardware.

Because live scanning is the product’s core feature, the first build treats this as a required device capability instead of shipping a non-functional fallback.

## OCR flow

1. DataScanner recognizes all visible text.
2. Low-confidence text is filtered.
3. Recognized items are converted into ScannedText:
   - transcript
   - bounding rectangle
   - confidence
4. TagClusterer groups nearby items.
5. PriceTagParser tries to create a ProductCandidate from each cluster.
6. The best two valid candidates are selected.
7. ComparisonEngine checks dimension compatibility and calculates the result.
8. ScannerModel stabilizes equivalent results before publishing them to the UI.

## Stabilization

Live OCR changes constantly. Publishing every frame would make the UI unusable.

Initial strategy:

- Build a semantic signature from normalized price + quantity + dimension for each candidate.
- Require the same pair to remain present for multiple updates / a short time window.
- Clear the result only after a grace period rather than immediately when one OCR item disappears for a frame.

Exact timing is a tunable implementation parameter and must be validated on-device.

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
