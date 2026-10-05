# Product Spec — Price Lens v1

## Product contract

### Confirmed requirements

- The product is an iPhone app.
- Primary input is the live camera.
- User points the camera at two price tags.
- The app recognizes price plus weight / volume / count.
- The app compares unit price in kg / L / item.
- The primary output is a direct statement such as “This one is 18% cheaper per kg”.
- Core use cases include supermarkets, cosmetics and household goods.
- No manual entry in the primary workflow.
- UI should feel like a normal camera with a minimal overlay.

### Derived requirements

- OCR results must be grouped into two price-tag candidates.
- Price and quantity must be associated with the correct tag.
- Quantities must be normalized before comparison.
- The system must refuse comparison when dimensions differ.
- Recognition needs temporal stabilization so the result does not flicker.
- Ambiguous recognition must resolve to a retry/guidance state, not a guessed winner.
- Camera permission denial and unsupported hardware need explicit states.
- A denied camera permission must offer a direct Settings recovery path and re-check permission when the app becomes active again.
- The parsing/comparison core must be testable without the camera.

## Supported notation in the first parser

### Price

Examples:

- 1.99
- 1,99
- €1.99
- 1,99 €
- 4.50 KM
- 4,50 BAM
- split OCR such as large `4` + small `99` / `99 €` when the fragments are spatially one price

A decimal amount with two fraction digits may be treated as a price even when the currency symbol is on a neighboring OCR line. Split whole/cents recognition is accepted only for nearby, aligned OCR fragments; unrelated numbers are rejected.

### Mass

- 250 g
- 500g
- 1 kg
- 1.5 kg
- 1,5 kg

### Volume

- 100 ml
- 330 ml
- 75 cl
- 1 L
- 1.5 l

### Count

- 1 pc
- 6 pcs
- 10 шт

### Multipack

- 6 x 330 ml
- 6 × 330 ml
- 4x250g

## Comparison rules

1. Convert mass to kilograms.
2. Convert volume to liters.
3. Keep count as items.
4. Compute unit price using Decimal arithmetic.
5. Compare only candidates with the same dimension.
6. Cheaper percentage is measured relative to the more expensive unit price:

   (expensive - cheap) / expensive × 100

## Result states

### Searching

Not enough usable OCR content is visible.

### One tag found

A valid price + quantity pair is available for one candidate.

### Comparing

Two valid comparable candidates are present but have not yet met stabilization requirements.

### Result

Two candidates are stable and comparable.

### Incompatible

Two valid candidates use different dimensions.

### Retry

OCR confidence or parsing confidence is below the safe threshold.

### Camera unavailable

Permission denied, restriction, unsupported hardware or scanner runtime failure. Permission denial offers an Open Settings action; returning to the app re-checks access without requiring a restart.

## UX contract

- Camera is always the dominant surface.
- No keyboard in the main flow.
- No form fields in the main flow.
- Guidance should be one short sentence.
- A successful result should be readable at a glance.
- The winner must be visually distinct without relying on color alone.
- UI must not cover the central price-tag area more than necessary.

## Acceptance examples

### Example A

Tag A: 4.99 for 500 g  
Tag B: 7.49 for 1 kg

A = 9.98 / kg  
B = 7.49 / kg

Result: B is ~25% cheaper per kg.

### Example B

Tag A: 2.10 for 500 ml  
Tag B: 2.80 for 750 ml

A = 4.20 / L  
B = 3.73 / L

Result: B is ~11% cheaper per L.

### Example C

Tag A: 6.00 for 6 pcs  
Tag B: 8.00 for 10 pcs

A = 1.00 / item  
B = 0.80 / item

Result: B is 20% cheaper per item.

### Example D

Tag A: 4.99 for 500 g  
Tag B: 4.99 for 500 ml

Result: no comparison; dimensions are incompatible.
