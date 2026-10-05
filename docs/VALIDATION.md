# Validation Plan

No validation result is claimed by this file. It defines checks that must be run against an identified build.

## Parser checks

- 1.99 + 500 g
- 1,99 + 500g
- € 4.50 + 1 kg
- 4,50 BAM + 1,5 l
- 6 x 330 ml
- 6 × 330 ml
- 10 pcs
- 10 шт
- reject missing price
- reject missing quantity
- reject unit-price-only text
- reject incompatible dimensions

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
