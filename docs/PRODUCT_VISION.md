# Product Vision — Price Lens

## What it is

Price Lens is an iPhone app that tells a shopper which of two products is actually cheaper after normalizing price by package size.

The interaction is intentionally simple: point the camera at two price tags and get a direct comparison.

## Who it is for

People shopping in supermarkets, cosmetics stores, pharmacies and household-goods stores who need to compare differently sized packs quickly.

## Problem

Shelf prices are easy to compare only when package sizes match. When one product is 400 g and another is 650 g, or 500 ml versus 750 ml, shoppers must calculate unit price mentally or use a calculator.

## Core workflow

1. Open Price Lens.
2. Point the iPhone camera at two price tags.
3. The app recognizes price and package quantity for both.
4. The app normalizes both to kg, L or item.
5. The app shows which is cheaper and by what percentage.

No manual entry is part of the core workflow.

## Core scope for v1

- iPhone only.
- Live camera scanning.
- Two products at a time.
- OCR for price and package quantity.
- Mass: g / kg.
- Volume: ml / cl / L.
- Count: item / pc / pcs / шт.
- Multipacks such as 6 × 330 ml.
- Automatic unit-price comparison.
- Clear retry state when recognition is insufficient.

## Important

- Stable result instead of flickering frame-by-frame guesses.
- Keep processing on-device where possible.
- Minimal camera-first UI.
- Do not show a winner when the inputs are not confidently comparable.

## Later

- More packaging notation and locale formats.
- History / favorites.
- Barcode/product recognition.
- Photo-library import.
- Localization expansion.
- Extended localization/accessibility polish after the core scanning flow is validated; basic accessible state/result/recovery behavior remains part of Validation.

## Out of scope for v1

- Accounts.
- Cloud backend.
- Manual price/weight forms.
- Android.
- Shopping lists.
- Store catalog integration.
- Cross-currency conversion.
- Coupon/loyalty-card logic.
- Tax comparison between regions.

## Constraints / engineering assumptions

- Native iOS.
- Initial deployment target: iOS 17+.
- Camera scanning uses Apple VisionKit / Vision APIs.
- DataScanner requires supported hardware; the first implementation targets A12 Bionic or newer.
- No image upload or remote OCR in the initial architecture.
- Comparison assumes both shelf prices use the same currency.

These assumptions are engineering defaults for the first build, not permanent product restrictions.

## Success criteria for the first validation milestone

- User can obtain a comparison without typing anything.
- Two supported labels in good light produce a stable comparison.
- Supported units normalize correctly.
- Mixed dimensions (for example kg vs L) never produce a false winner.
- Low-confidence or incomplete recognition asks the user to move closer / reframe instead of inventing a result.
- No camera frame is persisted or sent over the network.
- Target: comparison appears within 1.5 s after both valid labels are stably recognized on an iPhone 12-class device.
- Parser target for the initial test corpus: >= 90% correct extraction on supported clean label formats before user validation.
