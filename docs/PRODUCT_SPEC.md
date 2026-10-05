# Product Spec — Price Lens v1

## Product contract

### Confirmed requirements

- The product is an iPhone app.
- Primary input is the live camera.
- User scans one price label at a time.
- A recognized label shows a preview of price, package quantity and normalized unit price before it is added.
- User explicitly adds a recognized label to the current comparison.
- A comparison contains two or more products and can continue growing; the main UI does not impose a fixed two-item workflow.
- The app recognizes price plus weight / volume / count.
- The app compares unit price in kg / L / item across the whole comparison set.
- The primary output highlights the best unit price while keeping every added item visible and removable.
- Core use cases include supermarkets, cosmetics and household goods.
- No manual entry in the primary workflow.
- UI should feel like a normal camera with a minimal overlay.

### Derived requirements

- The live scanner must restrict recognition to a visible central comparison zone so surrounding shelf labels are not silently selected.
- The comparison zone is intentionally sized for one price label at a time.
- OCR results inside that zone must resolve to at most one valid product candidate before the Add action becomes available.
- If multiple valid labels are inside the zone, the app must refuse to guess and ask the user to center one label.
- Price and quantity must be associated with the same scanned label.
- Adding a product is deliberate: recognition alone never mutates the comparison set.
- Duplicate semantic candidates must not be silently added twice.
- Added products can be removed individually or cleared as a set.
- The current comparison set accepts only compatible dimensions and explicitly compatible currencies.
- Once two or more items are present, the lowest normalized unit price is marked as best; additional items can still be scanned and added.
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
- 229,99 ₽ / 229.99 RUB
- split Russian shelf price such as large `229` + small `99₽`
- 4 € / € 4
- 4,- € / 4.–
- grouped prices such as 1 299,99 / 1.299,99 / 1,299.99
- split OCR such as large `4` + small `99` / `99 €` when the fragments are spatially one price
- separate nearby currency fragments such as `4` + `€`
- missing decimal separator such as `4 99 €` when currency makes the intent unambiguous

A decimal amount with two fraction digits may be treated as a price even when the currency symbol is on a neighboring OCR line. Supported currency normalization includes EUR/€, USD/$, GBP/£, BAM/KM and RUB/₽. Unit-price lines such as `€/kg`, `per 100 g` and `per 100 ml` are not accepted as the package price. Integer-only prices require an adjacent explicit currency; zero-cents notation such as `4,-` is accepted without one. Split whole/cents recognition is accepted only for nearby, aligned OCR fragments; unrelated numbers are rejected. A missing decimal separator is repaired only when currency is explicit on the price item or a nearby currency fragment; bare `4 99` remains rejected.

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

No valid label is centered yet. Guidance asks the user to place one price label inside the scan target.

### Reading

One candidate is visible but has not yet met stabilization requirements.

### Ready to add

A stable candidate is visible. The UI shows the recognized package price, normalized quantity and unit price plus an explicit **Add** action.

### Already added

The centered candidate is already in the comparison. Guidance asks the user to move to another label.

### Multiple labels

More than one valid candidate is visible in the single-label scan target. No item is selected; the user is asked to center one label.

### Incompatible

The candidate uses a different dimension or explicit currency from the existing comparison set. It is not added automatically; the UI offers a clear way to start a new comparison.

### Comparison set

One or more previously added products remain visible in a horizontal tray. With two or more compatible items, the current best unit price is highlighted. Adding more products updates the best item automatically.

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
- The first screen must explain the workflow without prior instruction: **scan one label → review recognition → Add → scan the next**.
- Do not show a fixed `0/2` counter because the comparison may contain more than two items.
- The scan guide should use lightweight corner cues sized for one label rather than a dominant technical/debug-style rectangle.
- Guidance must stay compact and must not obscure the central scanning area.
- A stable recognized candidate must show what the app actually read before the user can add it.
- The primary Add action must be visually obvious and must not be confused with manual data entry.
- Added items remain visible in a horizontally scrollable comparison tray with individual remove actions.
- When two or more items exist, the best unit price is identified by text/symbol, not color alone.
- The user must be able to continue scanning additional items without leaving the camera flow.

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


## Multi-item acceptance

### Example E — three mass products

Item 1: 4.99 for 500 g → 9.98 / kg  
Item 2: 7.49 for 1 kg → 7.49 / kg  
Item 3: 8.10 for 1 kg → 8.10 / kg

Expected:

- all three items remain in the comparison tray;
- Item 2 is marked BEST;
- scanning a fourth compatible product remains available;
- no pair is chosen or discarded merely because the set contains more than two items.

### Example F — incompatible addition

Existing comparison: mass products.  
New candidate: 2.80 for 750 ml.

Expected:

- volume item is not added to the mass comparison;
- no winner changes;
- UI explains the unit mismatch and offers to start a new comparison.


## Real Russian shelf-label acceptance

A Russian promotional shelf label may contain:

- discount text such as `-15%`;
- an older/smaller price such as `269` + `99`;
- the current prominent price such as `229` + `99₽`;
- package quantity embedded in product text such as `200Г`;
- unrelated card/loyalty/product-code text.

For this format the parser must:

- select the prominent current `229.99 ₽` rather than the smaller old price;
- parse `200Г` as 0.2 kg;
- ignore discount percentages and unrelated integers;
- normalize `₽`, `RUB` and `РУБ` to the same currency;
- return no candidate rather than guess if price/quantity association is not defensible.


## Retail grammar coverage

Price-tag support is defined by grammar classes, not a finite retailer list.

Required classes include:

- Unicode digit normalization;
- locale decimal/grouping forms including spaces, NBSP, apostrophes and Indian grouping;
- currency symbol/code before, after or in the decimal position;
- Foundation ISO currency codes plus common symbols/retail aliases;
- split whole/cents OCR fragments;
- package-price suffixes such as `р/шт.`;
- metric, imperial and count unit aliases through a data-driven lexicon;
- multipacks;
- discount/reference-price rejection;
- old/current price geometry and prominence;
- safe ambiguity refusal.

The parser must never claim universal certainty. Unsupported or near-tied interpretations return no ProductCandidate.

See `docs/RETAIL_GRAMMAR.md`.
