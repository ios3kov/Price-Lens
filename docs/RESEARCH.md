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
