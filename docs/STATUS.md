# Development Status

## Current goal

First end-to-end Price Lens iPhone MVP:

camera -> on-device OCR -> exactly two price-tag candidates -> unit normalization -> comparison result.

## State

- Repository: ios3kov/Price-Lens
- Working branch: feat/initial-mvp
- Verified source commit: `e241b07059a9c494b3c83026274993d935c5c4ff`
- Standard baseline: AE Development Rules 8.0.0 @ `132b7cd32873ba7328e3128ffbb33e1929b74d45`
- Delivery gate: Development
- Risk profile: Standard
- Product Discovery: complete for initial v1 scope
- Reference Audit: not triggered; no concrete external product is a parity target
- Merge / Release: not authorized and not performed

## Implemented

- Native Swift / SwiftUI iPhone app, iOS 17+.
- VisionKit DataScanner live OCR, A12+ capability.
- Camera permission flow with Settings recovery.
- On-device processing; no backend, analytics or frame upload.
- Visible central comparison zone backed by the scanner region of interest.
- A/B overlays on recognized price tags.
- Refuses ambiguous frames with more than two valid tags.
- Parses decimal, comma-decimal, integer-with-currency, zero-cent and split whole/cents prices.
- Parses mass, volume, count and multipacks.
- Rejects unit-price text such as `€/kg` as package price.
- Refuses mixed dimensions and explicitly different currencies.
- Time-based recognition stabilization and brief OCR-dropout grace period.
- Pure production core is tested outside iOS Simulator via Swift Package.

## Internal verification

For source commit `e241b070`:

- GitHub Actions run: `37310658218`
- Xcode 16.4 (16F6)
- Swift 6.1.2
- iOS simulator build: PASS
- Unsigned iPhone device-target build: PASS
- Core unit tests: PASS — 50 executed, 0 failures
- Project TODO/FIXME/fatalError/debug-print audit: no findings
- Relevant source warnings: none

See `docs/EVIDENCE_INITIAL_MVP.md`.

## Remaining blocker

The camera workflow is **not yet validated on a physical iPhone**.

Before calling this a Validation Build, run the real-device scenarios in `docs/VALIDATION.md`, especially recognition accuracy, comparison-zone alignment, glare/angle behavior, timing and OCR dropout recovery.
