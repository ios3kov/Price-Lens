# Validation Plan

No validation result is claimed by this file. It defines checks that must be run against an identified build.

## Parser checks

The automated core corpus covers at minimum:

- dot and comma decimal prices;
- neighboring currency markers;
- split whole/cents OCR;
- g / kg / г;
- ml / cl / L / л;
- pc / pcs / items / шт;
- x / × multipacks;
- compact notation such as 250g and 4x250g;
- missing price;
- missing quantity;
- unit-price-only text;
- ambiguous decimal quantity such as 1.50 L;
- incompatible dimensions.

This corpus is regression evidence for deterministic parsing only. It does not prove camera OCR quality.

## Comparison checks

- equal prices
- left cheaper
- right cheaper
- percentage rounding
- Decimal precision
- mass normalization
- volume normalization
- count normalization

## Runtime checks on iPhone

- first camera permission grant
- permission denied
- permission restored
- scanner unavailable
- two labels side by side
- two labels vertically offset
- glare
- low light
- angled labels
- temporary OCR loss
- move camera from one pair of labels to another
- mixed mass/volume pair does not produce a winner

## Evidence to capture

For every validation build record:

- Git commit SHA
- Xcode version
- iOS version
- device model
- test date
- pass/fail per required check
- screenshots/video for observed UI behavior where useful
- known limitations

A successful compile alone is not runtime evidence.
