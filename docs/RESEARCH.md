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
