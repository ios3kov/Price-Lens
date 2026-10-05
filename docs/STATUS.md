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

## TASK-CLOSE-001 — current requirement / task / check mapping

This is the current scoped reconciliation for the first iPhone validation milestone.

| Requirement / obligation | Implementation block | Observable acceptance | Check / phase | Current status / Evidence |
| --- | --- | --- | --- | --- |
| Camera-only primary workflow; no manual entry | VisionKit scanner + SwiftUI camera UI | User can compare without typing | pre-handoff: source/build review; user-validation: live camera | Implementation PASS; runtime NOT RUN |
| Exactly two products are compared | clustering + deduplication + CandidatePairSelector | 0/1/3+ candidates never produce a false pair | pre-handoff: unit tests | PASS — verified source `7baf84b6`, 65/65 suite |
| Price + quantity stay associated with the same tag | geometry clustering + recursive split guards | no cross-tag price/quantity pairing | pre-handoff tests + user-validation fixtures | Automated PASS; live camera NOT RUN |
| Unit normalization is correct | Decimal parser / ComparisonEngine | g↔kg, ml/cl↔L, count and multipacks yield correct unit price | pre-handoff: unit tests | PASS |
| Ambiguous/unit-price text does not create a false winner | parser rejection rules | `/kg`, `per 100 g/ml`, unsupported ambiguity do not become package price | pre-handoff: regression tests | PASS |
| Camera lifecycle recovers safely | permission recovery, Try Again, background reset | no stale result after background; denied permission can recover | pre-handoff: compile/review; user-validation: real device | Implementation PASS; runtime NOT RUN |
| A/B overlays correspond to actual tags | DataScanner bounds + overlay | frames A/B align with intended two labels | user-validation: physical iPhone | NOT RUN |
| Live OCR is useful on real shelf labels | DataScanner `.accurate` + ROI + stabilization | controlled fixtures and real shelf labels produce correct result | user-validation: physical iPhone | NOT RUN |
| Performance target | stabilization / on-device processing | useful result <= 1.5 s after stable readable framing | user-validation: physical iPhone timing | NOT RUN |
| Artifact identity for validation | exact Git commit + local signed Xcode build | installed test build is traceable to exact source commit | pre-handoff/user-validation boundary | BLOCKED until signed local build exists |
| Merge / public release | explicit user authorization required | no merge/publication without command | permission boundary | NOT AUTHORIZED / NOT PERFORMED |

### Reconciliation result

- Product contract still covers the current scope; no new Stage 0 is required.
- Reference Audit remains N/A because there is no concrete external parity target.
- Internal pre-handoff evidence for source `7baf84b6`: simulator build PASS, unsigned `iphoneos` build PASS, 65/65 core tests PASS, source hygiene audit PASS.
- Required user-validation items remain intentionally NOT RUN: physical camera OCR, overlay alignment, lifecycle behavior on device, real-shelf behavior and timing.
- These NOT RUN items are the purpose of the next Validation phase; they must not be reported as PASS before device evidence exists.
- No cleanup action is required before validation: repository has no known temporary/debug source artifacts that affect the validation candidate.
- Current completion claim is therefore: **implementation and internal pre-handoff checks complete for the scoped MVP; physical iPhone validation is still required.**
