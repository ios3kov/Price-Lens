# Development Status

## Current goal

Build the first end-to-end Price Lens iPhone vertical slice:

camera -> OCR -> two tag candidates -> unit normalization -> winner.

## State

- Repository: ios3kov/Price-Lens
- Working branch: feat/initial-mvp
- Standard baseline: AE Development Rules 8.0.0 @ 132b7cd32873ba7328e3128ffbb33e1929b74d45
- Delivery gate: Development
- Initial risk profile: Standard
- Product Discovery: complete for initial v1 scope
- Reference Audit: not triggered; no concrete external product is a parity target
- Release: not authorized / not in scope

## Confirmed product decisions

- iPhone.
- Camera-first.
- Two price tags.
- Automatic price + size recognition.
- Compare by kg / L / item.
- No manual entry in the core workflow.
- Minimal camera overlay.

## Engineering decisions for first build

- Native Swift / SwiftUI.
- VisionKit DataScanner for live OCR.
- On-device processing.
- iOS 17+ initial target.
- A12+ required capability.
- Parser and comparison logic isolated from camera APIs.

## Current implementation block

1. Repository scaffold.
2. Product contract.
3. Technical design.
4. Pure parsing/comparison core.
5. Live scanner adapter.
6. Minimal result UI.
7. Unit tests.
8. Build/test evidence.

## Next validation blocker

A real-device build and camera test is required before the scanning workflow can be claimed as validated.
