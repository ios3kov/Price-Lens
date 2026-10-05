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

- The live scanner must restrict recognition to a visible central comparison zone so surrounding shelf labels are not silently selected.
- OCR results inside that zone must be grouped into two price-tag candidates.
- If more than two valid price tags are present, the app must refuse to choose a pair automatically and ask the user to tighten the frame.
- Price and quantity must be associated with the correct tag.
- Quantities must be normalized before comparison.
- The system must refuse comparison when dimensions differ.
- Recognition needs temporal stabilization so the result does not flicker.
- Ambiguous recognition must resolve to a retry/guidance state, not a guessed winner.
- Camera permission denial and unsupported hardware need explicit states.
- A denied camera permission must offer a direct Settings recovery path and re-check permission when the app becomes active again.
- Leaving the app must clear any published comparison and tear down the active scanner session so returning cannot show a stale result.
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
- 4 € / € 4
- 4,- € / 4.–
- grouped prices such as 1 299,99 / 1.299,99 / 1,299.99
- split OCR such as large `4` + small `99` / `99 €` when the fragments are spatially one price
- separate nearby currency fragments such as `4` + `€`
- missing decimal separator such as `4 99 €` when currency makes the intent unambiguous

A decimal amount with two fraction digits may be treated as a price even when the currency symbol is on a neighboring OCR line. Unit-price lines such as `€/kg`, `per 100 g` and `per 100 ml` are not accepted as the package price. Integer-only prices require an adjacent explicit currency; zero-cents notation such as `4,-` is accepted without one. Split whole/cents recognition is accepted only for nearby, aligned OCR fragments; unrelated numbers are rejected. A missing decimal separator is repaired only when currency is explicit on the price item or a nearby currency fragment; bare `4 99` remains rejected.

### Mass

- 250 g
- 500g
- 1 kg
- 1.5 kg
- 1,5 kg
- grouped base-unit quantities such as 1 000 g / 1.500 g

### Volume

- 100 ml
- 330 ml
- 75 cl
- 1 L
- 1.5 l
- grouped base-unit quantities such as 1 500 ml / 1,500 ml

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

### Too many tags

More than two valid candidates are inside the comparison zone. No pair is selected; the user is asked to move closer.

### Comparing

Two valid comparable candidates are present but have not yet met stabilization requirements.

### Result

Two candidates are stable and comparable.

### Incompatible

Two valid candidates use different dimensions.

### Retry

OCR confidence or parsing confidence is below the safe threshold.

### Camera unavailable

Permission denied, restriction, unsupported hardware or scanner runtime failure. Permission denial offers an Open Settings action; returning to the app re-checks access without requiring a restart. A transient scanner/runtime failure offers Try Again without restarting the app.

## UX contract

- Camera is always the dominant surface.
- No keyboard in the main flow.
- No form fields in the main flow.
- Guidance should be one short sentence.
- A successful result should be readable at a glance.
- The winner must be visually distinct without relying on color alone.
- UI must not cover the central price-tag area more than necessary.
- A subtle comparison-zone guide must match the actual OCR region of interest.
- The camera viewfinder must visually fill the screen; large unexplained letterbox areas are not acceptable in the primary scanning state.
- The user must understand recognition progress at a glance: 0/2, 1/2, 2/2 or too many labels.
- The scan guide should use lightweight corner cues rather than a dominant technical/debug-style rectangle.
- Guidance must stay compact and must not obscure the central scanning area.
- A/B markers must appear directly on the recognized labels and map unambiguously to the result card.
- The primary scanning state requires no tap; this must be stated clearly in the first-use guidance.
- The result should appear as a compact comparison sheet with the cheaper option identified by text/symbol, not color alone.

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
