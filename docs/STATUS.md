# Development Status

## Current goal

First end-to-end Price Lens iPhone MVP:

camera -> on-device OCR -> exactly two price-tag candidates -> unit normalization -> comparison result.

## State

- Repository: ios3kov/Price-Lens
- Working branch: feat/initial-mvp
- Verified source commit: `7baf84b6d3a9310cd322559a303e2c1f9afc070b`
- Standard baseline: AE Development Rules 8.0.0 @ `132b7cd32873ba7328e3128ffbb33e1929b74d45`
- Delivery gate: Development
- Risk profile: Standard
- Product Discovery: complete for initial v1 scope
- Reference Audit: not triggered; no concrete external product is a parity target
- Merge / Release: not authorized and not performed

## Implemented

- Native Swift / SwiftUI iPhone app, iOS 17+.
- VisionKit DataScanner live OCR with `.accurate` quality and A12+ capability requirement.
- Camera permission flow with Settings recovery and transient-failure retry.
- Background / foreground lifecycle resets recognition and recreates the scanner session.
- On-device processing; no backend, analytics or frame upload.
- Visible central comparison zone backed by the scanner region of interest.
- A/B overlays on recognized price tags.
- Refuses ambiguous frames with more than two deduplicated valid tags.
- Parses dot/comma decimal, grouped, integer-with-currency, zero-cent, fragmented whole/cents and missing-separator prices.
- Supports nearby standalone currency OCR fragments.
- Parses mass, volume, count and multipacks.
- Handles grouped base-unit quantities such as `1.500 g` and `1,500 ml` without a ×1000 error.
- Rejects unit-price text such as `€/kg`, `per 100 g` and `per 100 ml` as package price.
- Refuses mixed dimensions and explicitly different currencies.
- Time-based recognition stabilization and brief OCR-dropout grace period.
- Pure production core is tested outside iOS Simulator via Swift Package.
- Controlled camera fixtures are included for reproducible physical-device validation.

## Internal verification

For source commit `7baf84b6`:

- GitHub Actions run: `37313009533`
- Xcode 16.4 (16F6)
- Swift 6.1.2
- iOS simulator build: PASS
- Unsigned iPhone device-target build: PASS
- Core unit tests: PASS — 65 executed, 0 failures
- Project TODO/FIXME/fatalError/debug-print audit: no findings
- Relevant source warnings: none

See `docs/EVIDENCE_INITIAL_MVP.md`.

## Remaining blocker

The live camera workflow is **not yet validated on a physical iPhone**.

The next step is the runtime gate in `docs/IPHONE_VALIDATION.md`: controlled fixtures first, then real shelf labels. Any false winner, wrong unit normalization, cross-tag pairing, A/B mismatch, stale result or unrecoverable camera state is blocking.
