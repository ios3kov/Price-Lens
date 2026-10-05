# Privacy Inventory — Price Lens

Baseline: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`
Reviewed: 2026-10-05

## Current data flows

| Data / signal | Purpose | Location / recipient | Persistence | Tracking / identity |
| --- | --- | --- | --- | --- |
| Live camera frames | Recognize price tags and package size | Apple VisionKit + app process on device | Not persisted by Price Lens | No tracking; not linked to an account |
| Recognized OCR text / bounds | Build two product candidates | App memory on device | Not persisted | No tracking; no identity |
| Normalized price / quantity / comparison | Show cheaper unit price | App memory on device | Not persisted | No tracking; no identity |
| `ProcessInfo.systemUptime` | Measure elapsed time for recognition stabilization | App process on device | Not persisted or transmitted | Required Reason API; no tracking |

## Permissions

- Camera only.
- `NSCameraUsageDescription`: “Price Lens uses the camera to compare price tags and package sizes.”
- Denied/restricted access has an explicit recovery state.
- No Photos, Contacts, Location, Microphone, Notifications or ATT permission is requested in v1.

## Network / SDK / storage inventory

Current v1 has:

- no backend;
- no analytics SDK;
- no advertising/tracking SDK;
- no third-party runtime SDK;
- no account/auth;
- no user database;
- no app-owned photo/frame persistence;
- no remote OCR.

The Swift Package used by CI exposes the same app-owned core sources for host tests; it is not an embedded third-party runtime SDK.

## Privacy manifest

`PriceLens/PrivacyInfo.xcprivacy` declares:

- tracking: false;
- collected data types: none;
- Required Reason API category: `NSPrivacyAccessedAPICategorySystemBootTime`;
- approved reason: `35F9.1`.

Reason `35F9.1` is used only to measure elapsed time between recognition events inside the app. The uptime value is not persisted or transmitted.

CI verifies the privacy manifest is present in the built device `.app`, validates its plist syntax, and checks the exact category/reason.

## Validation / release boundary

For local physical-iPhone Validation, verify camera permission states and confirm no unexpected network/storage behavior appears.

Before App Store Release, separately verify current App Store privacy labels, privacy/support URLs, Xcode privacy report, final archive contents and any dependencies present in the exact release candidate. Those Release checks are not claimed here.
