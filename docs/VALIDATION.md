# Validation Plan

This document defines checks for an identified build. Passing CI does not prove live-camera behavior.

## Automated core coverage

The current regression suite covers:

- dot and comma decimal prices;
- integer price with explicit currency;
- European zero-cents notation;
- neighboring currency markers;
- split whole/cents OCR with geometry guards;
- g / kg / г;
- ml / cl / L / л;
- pc / pcs / items / шт;
- x / × multipacks;
- compact notation such as 250g and 4x250g;
- missing price / missing quantity;
- unit-price-only text;
- quantity-like decimal text such as 1.50 L;
- different currencies;
- incompatible dimensions;
- side-by-side and vertically stacked tag clustering;
- A/B candidate ordering;
- comparison-zone geometry;
- time-based recognition stabilization.

For verified source commit `61653ae9`, CI executed 33 tests with 0 failures.

## Required runtime checks on physical iPhone

### Camera lifecycle

- first camera permission grant;
- permission denied;
- Open Settings -> grant permission -> return without restarting app;
- scanner unavailable state;
- background / foreground return does not show a stale result.

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
- integer price with currency;
- zero-cents notation;
- large whole number + small cents split into separate OCR items;
- shelf tag containing both package price and `price / kg` -> package price wins.

### Conditions

- glare;
- low light;
- angled labels;
- small type;
- temporary OCR loss and recovery;
- quick camera movement.

### Comparison safety

- g vs kg;
- ml/cl vs L;
- multipacks;
- count;
- equal unit prices;
- mixed mass / volume -> no winner;
- explicit different currencies -> no winner.

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

A successful compile or simulator run alone is not runtime camera evidence.
