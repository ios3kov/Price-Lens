# API Research — Initial Scanner

Date: 2026-10-05

## Decision

Use VisionKit `DataScannerViewController` for the first live OCR implementation.

## Verified Apple API facts

- `DataScannerViewController` scans live camera video for text and supports recognizing multiple items.
- Recognized text exposes the transcript and bounds in view coordinates.
- The scanner provides delegate callbacks when recognized items are added, updated or removed.
- `isSupported` must be checked before use.
- Apple documents A12 Bionic or newer as the hardware requirement for DataScanner support.
- Camera usage requires `NSCameraUsageDescription`.

## Sources

- Apple Developer Documentation — DataScannerViewController
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller
- Apple Developer Documentation — RecognizedItem.Text
  https://developer.apple.com/documentation/visionkit/recognizeditem/text
- Apple Developer Documentation — DataScannerViewControllerDelegate
  https://developer.apple.com/documentation/visionkit/datascannerviewcontrollerdelegate
- Apple Developer Documentation — isSupported
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/issupported

## Architecture consequence

VisionKit is behind an app-owned adapter. Parsing and comparison do not depend on VisionKit types.

If on-device validation shows insufficient grouping control, frame rate or OCR quality, the scanner boundary can be replaced with AVFoundation + Vision without rewriting the comparison core.


## OCR quality level

Initial implementation uses `DataScannerViewController.QualityLevel.accurate`.

Apple documents `.accurate` as the mode that prioritizes recognition accuracy and specifically recommends it for smaller text and barcodes. Shelf-label text is frequently small, so correctness is the safer initial tradeoff for Price Lens.

Source:

- Apple Developer Documentation — DataScannerViewController.QualityLevel.accurate
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/qualitylevel-swift.enum/accurate
- Apple Developer Documentation — qualityLevel
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/qualitylevel-swift.property

The performance cost must still be measured on the physical validation device against the <= 1.5 s end-to-end target.

## AS 4.1 targeted platform research

Checked: 2026-10-05
Adopted standard: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

### Questions

1. Is VisionKit DataScanner still appropriate for the core camera workflow?
2. Is `.accurate` still the right initial quality choice for small shelf text?
3. What privacy declarations are required by the APIs Price Lens actually calls?

### Apple primary sources checked

- DataScanner `isSupported`:
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/issupported
  - A12 Bionic or later is still required.
  - Apple documents `iphone-ipad-minimum-performance-a12` for apps whose core functionality requires DataScanner.

- DataScanner quality:
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/qualitylevel-swift.enum/accurate
  - `.accurate` prioritizes recognition accuracy and is intended for smaller text/barcodes.
  - Recognition-speed impact remains a physical-device validation question.

- Camera purpose string:
  https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription
  - Camera access requires `NSCameraUsageDescription`.
  - Price Lens already provides a user-facing camera purpose string.

- `ProcessInfo.systemUptime`:
  https://developer.apple.com/documentation/foundation/processinfo/systemuptime
  https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
  - `systemUptime` is a Required Reason API in `NSPrivacyAccessedAPICategorySystemBootTime`.
  - Reason `35F9.1` applies to measuring elapsed time between events inside the app.
  - Price Lens uses uptime only for recognition stabilization and does not persist or transmit the value.

- Privacy manifests:
  https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
  https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
  - Required Reason API usage must be declared in `PrivacyInfo.xcprivacy`.
  - The manifest must be bundled in the app target.

### Decision / alternatives

Keep the current VisionKit adapter and monotonic stabilization design.

Alternative considered for stabilization: wall-clock timestamps. Rejected because wall-clock changes are a worse basis for short elapsed-time logic. The existing monotonic API matches the behavior we need; the correct fix is to declare its approved reason rather than hide or replace the usage.

### Verification

CI must verify that the built device `.app` contains `PrivacyInfo.xcprivacy`, that the bundle identity is the expected validation identity, and that the manifest declares:

- `NSPrivacyAccessedAPICategorySystemBootTime`;
- reason `35F9.1`;
- tracking = false.

This research does not replace physical-iPhone camera validation.

## Camera-first UX research after physical validation

Checked: 2026-10-05

Trigger: physical iPhone validation exposed a first-use UX failure even though the scanner itself launched.

### Apple guidance checked

- Human Interface Guidelines — Camera Control:
  https://developer.apple.com/design/human-interface-guidelines/camera-control
  - maximize the height and width of the viewfinder;
  - minimize distractions in the viewfinder;
  - keep controls contextual and avoid unnecessary duplication.

- Apple design principles:
  https://developer.apple.com/design/human-interface-guidelines/design-principles
  - simplicity: be clear and direct;
  - stay out of the way of the task;
  - every interface element should earn its place.

- VisionKit — Scanning data with the camera:
  https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera
  - DataScanner provides the live camera surface and item geometry;
  - custom recognition feedback/highlights are appropriate when the app owns the action logic.

### Physical validation finding

Candidate `8450963d` launched on the user's iPhone and displayed the scanner, but the first screen was reported as confusing and visually unfinished.

Observed issues from the user-provided screenshot:

- camera preview did not read as an edge-to-edge viewfinder because large black areas dominated the top/bottom;
- a large dashed rectangle read as a technical debug overlay rather than a consumer scanner;
- the bottom instruction card obscured too much of the camera;
- state was not glanceable: user could not immediately see 0/2, 1/2 or 2/2 labels found;
- A/B labels were not explained by the first-use hierarchy;
- branding competed with the primary action.

### Decision

Retain the camera-only workflow and OCR architecture. Redesign only the presentation/scanner sizing:

- force the camera surface to fill the available screen;
- reduce the scan guide to four subtle corners;
- add a compact 0/2 → 1/2 → 2/2 progress indicator;
- keep a single compact bottom status panel;
- preserve A/B labels directly on recognized tags;
- make the result a concise bottom comparison sheet;
- add one success haptic per newly stabilized semantic pair;
- retain Reduce Motion and VoiceOver behavior.

No new navigation, manual input, settings flow or product scope is introduced.

### Verification

Fresh CI is required because production UI bytes change. Then the new candidate must be reinstalled and the original first-screen symptom rechecked on the physical iPhone before the UX finding can be closed.

## Sequential multi-item capture UX research

Checked: 2026-10-05

Trigger: physical iPhone validation showed that the simultaneous-two-label model remained unclear and did not answer the user's "what if I need more than two?" use case.

### Apple sources checked

- VisionKit — Scanning data with the camera:
  https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera
  - DataScanner continuously tracks recognized items in live video.
  - The app is expected to provide its own feedback and actions for recognized content.
  - Custom highlights/actions are compatible with the scanner model.

- DataScannerViewController:
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller
  - `recognizedItems` / delegate updates expose current recognized content.
  - `regionOfInterest` can restrict the scanned area.
  - `overlayContainerView` supports app-owned recognition feedback.

- Camera Control HIG:
  https://developer.apple.com/design/human-interface-guidelines/camera-control
  - maximize usable viewfinder area;
  - minimize distracting controls in the viewfinder;
  - keep camera UI contextual.

### Options considered

1. **Keep two labels simultaneously visible.**
   - Rejected by physical UX evidence.
   - Does not scale beyond two.
   - Makes tag association and "what next?" unclear.

2. **Auto-capture every stable label while the user pans.**
   - Rejected for v1.
   - Too easy to add accidental shelf labels without user intent.

3. **Sequential deliberate capture: scan one → preview → Add → scan next.**
   - Selected.
   - Preserves camera-only data entry while making the mutation explicit.
   - Scales naturally to 3+ products.
   - Lets the user verify recognized price/quantity before adding.
   - Reduces accidental cross-tag comparison.

### Decision

Use a smaller one-label ROI and keep `recognizesMultipleItems=true` because a single shelf label still contains multiple OCR fragments (price, size, currency, etc.).

The app groups those fragments into one ProductCandidate. If more than one valid product candidate exists in the ROI, Add is not enabled and the user is asked to center one label.

A stable candidate is never inserted automatically. The explicit **Add** action creates/extends an in-memory ComparisonSession. The session has no fixed two-item UI limit and ranks all compatible added products by normalized unit price.

### Verification

Required before closing the workflow change:

- fresh core tests for 3+ session items, ranking, duplicate rejection, unit mismatch and currency mismatch;
- fresh simulator/device-target build;
- physical iPhone check that the first-use workflow is self-explanatory;
- physical test adding at least three products;
- confirm earlier items remain visible/removable while scanning the next;
- confirm incompatible candidate never changes the existing winner.

## Russian shelf-label OCR follow-up

Checked: 2026-10-05

Trigger: physical iPhone validation of candidate `d33616b9` showed the camera and ROI working, but a real Russian promotional shelf label produced no parsed candidate.

Observed label characteristics:

- Cyrillic product text;
- quantity embedded as `200Г`;
- current price visually split as large `229` + small `99₽`;
- smaller previous price `269` + `99`;
- discount percentage and unrelated integers.

### Apple source check

- VisionKit `text(languages:textContentType:)`:
  https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/recognizeddatatype/text(languages:textcontenttype:)
  - language identifiers act as recognition-priority hints;
  - passing an empty list uses the person's preferred languages;
  - the scanner still recognizes all supported languages.

- VisionKit — Scanning data with the camera:
  https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera
  - when the expected content includes other languages, pass language identifiers as hints;
  - use `supportedTextRecognitionLanguages` to discover current support.

### Decision

Keep VisionKit/DataScanner. Do not replace the OCR stack yet.

Change two bounded layers:

1. **OCR language priorities**
   - build language hints dynamically from the user's preferred languages;
   - additionally prioritize a supported Russian language identifier and English when available;
   - never invent an unsupported identifier: hints are selected from `supportedTextRecognitionLanguages`.

2. **Parser / currency**
   - add `₽`, `RUB`, `РУБ` support everywhere price fragments/currency are parsed;
   - normalize them to one RUB currency identity;
   - add a regression fixture with current price `229 + 99₽`, old `269 + 99`, discount text and `200Г`.

### Diagnostic UX

A new `Text found` scan state distinguishes:

- no OCR text seen at all; from
- OCR text exists but the app still cannot form a supported price + quantity candidate.

This is useful product feedback and also makes future physical OCR failures diagnosable without a debug build.

### Verification

Required:

- fresh simulator and unsigned-device build;
- fresh parser regression suite;
- physical retest against the same Russian shelf label;
- if the app shows `Text found` but never `Label ready`, collect the observed OCR transcripts in a bounded diagnostic follow-up instead of guessing another parser fix.
