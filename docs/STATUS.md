# Development Status

## Current goal

First end-to-end Price Lens iPhone MVP:

camera -> on-device OCR -> exactly two price-tag candidates -> unit normalization -> comparison result.

## State

- Repository: ios3kov/Price-Lens
- Working branch: feat/initial-mvp
- Validation candidate source commit: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06`
- Standard baseline: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`
- Previous baseline: AE Development Rules 8.0.0 @ `132b7cd32873ba7328e3128ffbb33e1929b74d45` (historical only)
- Delivery gate: Validation
- Risk profile: Standard
- Applicable modules: iOS; Privacy/Permissions; Accessibility; Validation/Release
- Out of current scope: Backend; StoreKit; UGC/AI/Kids; Hybrid; Games
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
- `PrivacyInfo.xcprivacy` declares the System Boot Time Required Reason API with approved reason `35F9.1`.
- CI verifies the manifest inside the built device `.app` and verifies Bundle ID/version/build.
- Result accessibility exposes winner plus A/B normalized unit prices; candidate-frame animation respects Reduce Motion.

## Internal verification

For validation candidate source commit `8450963d`:

- GitHub Actions run: `37316764549`
- Xcode 16.4 (16F6)
- Swift 6.1.2
- iOS Simulator build: PASS
- Unsigned iPhone device-target build: PASS
- Built device bundle identity: PASS — `com.os3kov.PriceLens` `0.1.0 (1)`
- Bundled privacy manifest: PASS
- Required Reason API: PASS — `NSPrivacyAccessedAPICategorySystemBootTime / 35F9.1`
- Tracking declaration: PASS — false
- Core unit tests: PASS — 65 executed, 0 failures
- Relevant source warning: only AppIntents metadata extraction skipped because AppIntents is not linked; non-blocking

Historical Evidence for earlier commits remains unchanged. See:
- `docs/EVIDENCE_INITIAL_MVP.md` — historical pre-AS baseline
- `docs/EVIDENCE_AS_4_1_VALIDATION_PREP.md` — current AS 4.1 candidate

## Remaining blocker

The live camera workflow is **not yet validated on a physical iPhone**.

Next required step: use `docs/LOCAL_IPHONE_VALIDATION_PACKAGE.md` to build and install the exact clean candidate `8450963d` through local Xcode signing, record the installed identity in `docs/BUILD_IDENTITY_VALIDATION.md`, then execute `docs/DEVICE_QA.md`: controlled fixtures first, real shelf labels second.

Blocking runtime failures include any false winner, wrong unit normalization, cross-tag pairing, A/B mismatch, stale result, inaccessible critical recovery/result state, unexpected data flow, or unrecoverable camera state.

## AS 4.1 SCOPE / COMPLETE — current requirement / task / check mapping

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
| Privacy Required Reason API | bundled PrivacyInfo + CI bundle inspection | exact System Boot Time reason 35F9.1 exists in built app | pre-handoff | PASS on 8450963d |
| Basic accessibility | SwiftUI semantics + Reduce Motion + result accessibility value | critical result/recovery state is understandable without color-only cues | pre-handoff compile/review + user-validation device checks | Implementation PASS; device checks NOT_RUN |
| Artifact identity for validation | exact Git commit + bundle ID/version/build + local signed Xcode install | installed test build is traceable to exact candidate | pre-handoff/user-validation boundary | unsigned identity PASS; signed installed identity NOT_RUN |
| Merge / public release | explicit user authorization required | no merge/publication without command | permission boundary | NOT AUTHORIZED / NOT PERFORMED |

### Reconciliation result

- Product contract still covers the current scope; no new discovery is required.
- Reference Audit remains N/A because there is no concrete external parity target.
- AS Development Rules 4.1.0 is explicitly adopted for current work.
- Targeted Apple research for DataScanner, camera permission and required-reason privacy APIs is recorded in `docs/RESEARCH.md`.
- Current pre-handoff Evidence for source `8450963d`: simulator build PASS, unsigned `iphoneos` build PASS, bundle identity PASS, privacy manifest PASS, 65/65 core tests PASS.
- Physical iPhone camera, overlay, lifecycle, accessibility, timing and real-shelf checks remain NOT_RUN and are the purpose of the Validation phase.
- App Store metadata, final privacy labels/policy URLs, archive/export and submission checks belong to Release and are not claimed by this Validation milestone.
- Merge / public release remain unauthorized.
- Current claim: **AS 4.1 pre-handoff checks are complete for candidate 8450963d; physical iPhone Validation is the next gate.**

## Release-only open scope

These items do **not** block the current local iPhone Validation gate, but they remain open for a future App Store Release:

- app icon / asset catalog and final launch presentation;
- final App Store screenshots, description, age rating and review notes;
- support URL and privacy-policy URL;
- final App Store privacy labels and Xcode privacy report from the exact release archive;
- Release archive/export identity, symbols and signing/provisioning review;
- minimum/stable OS compatibility matrix required for the declared Release support;
- final physical accessibility/localization pass for declared languages;
- current Apple submission / SDK / account / agreements / export-compliance checks;
- App Store upload, review and publication — not authorized.

None of these may be retroactively marked PASS from the current Validation evidence.
