# Validation Plan

This document defines checks for an identified build. Passing CI does not prove live-camera behavior.

## Automated core coverage

The current regression suite covers:

- dot, comma and grouped decimal prices;
- integer price with explicit or nearby standalone currency;
- European zero-cents notation;
- split whole/cents OCR with geometry guards;
- missing decimal separator repair only when currency disambiguates it;
- g / kg / г;
- ml / cl / L / л;
- pc / pcs / items / шт;
- grouped base-unit quantities such as 1.500 g and 1,500 ml;
- x / × multipacks, including grouped package size;
- compact notation such as 250g and 4x250g;
- missing price / missing quantity;
- unit-price-only text, including per-100g / per-100ml cases;
- quantity-like decimal text such as 1.50 L;
- different currencies;
- incompatible dimensions;
- recursive 3+ tag clustering;
- candidate deduplication and refusal to select a pair from 3+ valid tags;
- side-by-side and vertically stacked tag ordering;
- comparison-zone geometry;
- time-based recognition stabilization and dropout gating.

For verified source commit `7baf84b6`, CI executed 65 tests with 0 failures.

## Required runtime checks on physical iPhone

Start with `docs/IPHONE_VALIDATION.md` and `validation/price-tag-fixtures.html`.

### Camera lifecycle

- first camera permission grant;
- permission denied;
- Open Settings -> grant permission -> return without restarting app;
- scanner unavailable -> Try Again;
- background / foreground return clears the old result and restores a fresh scanner.

### Recognition / targeting

- exactly two labels side by side;
- exactly two labels vertically stacked;
- 3+ valid labels inside the comparison zone -> no automatic pair selection;
- labels outside the comparison zone are ignored;
- A/B overlays visually match the recognized labels;
- move camera from one pair to another without A/B swapping incorrectly.

### Price formats

- normal decimal price;
- comma decimal price;
- grouped price;
- integer price with same-line currency;
- integer price with a separate currency fragment;
- zero-cents notation;
- large whole number + small cents split into separate OCR items;
- missing decimal separator such as `4 99 €`;
- shelf tag containing both package price and `price / kg` or `per 100 g/ml`.

### Quantity formats

- g vs kg;
- ml / cl vs L;
- `1 000 g`;
- `1.500 g`;
- `1,500 ml`;
- multipacks;
- count.

### Conditions

- glare;
- low light;
- angled labels;
- small type;
- temporary OCR loss and recovery;
- quick camera movement.

### Comparison safety

- equal unit prices;
- mixed mass / volume -> no winner;
- explicit different currencies -> no winner;
- any 3+ valid candidates -> no winner.

### Timing

Target on iPhone 12-class hardware:

- UI remains responsive;
- result appears after the same pair is stable for roughly 350 ms;
- brief OCR dropout does not flicker away a published result;
- end-to-end useful result target remains <= 1.5 s after both tags are stably readable.

## Evidence to capture

For each physical-device validation run record:

- Git commit SHA;
- Xcode version;
- iOS version;
- device model;
- test date;
- PASS / FAIL / BLOCKED per required scenario;
- screenshots or short video for overlay/timing issues where useful;
- known limitations.

CI compiles both the simulator target and an unsigned `iphoneos` device target. These builds prove compilation only; they do not replace physical-camera runtime evidence.
