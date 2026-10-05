# Device QA — Price Lens Validation Candidate

Current OCR-fix retest candidate: `7a25dbceb00926a868c5686934c3059e0269e932`
Previous multi-item physical candidate: `d33616b9ae39ecae6ffc3054e8ade20afe7745cf` — Russian ₽ OCR FAIL
Historical physical candidates:
- `a2d9d9e0f6c2536335f19deecd7b12b9d4c98013` — workflow UX FAIL
- `8450963dc1db139d2bed9e1b3fea3e0a3236ae06` — first-use UX FAIL
Baseline: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

The M01–M15 table is the primary acceptance set for the current multi-item candidate and defaults to NOT_RUN until observed on the physical iPhone. Earlier D-series scenarios remain useful regression coverage where still applicable; old simultaneous-pair assumptions are historical only.

| ID | Scenario | Expected | Status | Evidence / issue |
| --- | --- | --- | --- | --- |
| D01 | Local signed install | Candidate installs and launches | NOT_RUN | |
| D02 | First launch + camera grant | Camera prompt explains purpose; scanner opens | NOT_RUN | |
| D03 | Camera denied | Recovery UI shown; Open Settings works | NOT_RUN | |
| D04 | Grant after denial | Return from Settings restores fresh scanner without app restart | NOT_RUN | |
| D05 | Background with visible result | Returning never shows stale result | NOT_RUN | |
| D06 | Cold / warm launch | No white frame, stuck loader or stale splash/state | NOT_RUN | |
| D07 | Controlled fixture: basic mass | Correct A/B and winner | NOT_RUN | |
| D08 | Controlled fixture: comma decimal / volume | Correct A/B and winner | NOT_RUN | |
| D09 | Controlled fixture: split cents | `4` + `99 €` parses as 4.99 | NOT_RUN | |
| D10 | Controlled fixture: unit-price trap | `/kg` / `per 100 g/ml` does not become package price | NOT_RUN | |
| D11 | Controlled fixture: 3 tags | No automatic pair; Too many price tags | NOT_RUN | |
| D12 | Controlled fixture: grouped quantity | 1.500 g / 1,500 ml normalized correctly | NOT_RUN | |
| D13 | Controlled fixture: missing separator | `4 99 €` safely repairs to 4.99 | NOT_RUN | |
| D14 | Side-by-side real labels | Correct pair, bounds and result | NOT_RUN | |
| D15 | Vertically stacked labels | Correct ordering and result | NOT_RUN | |
| D16 | Glare / angle / small type | No false winner; retry guidance if uncertain | NOT_RUN | |
| D17 | Temporary OCR loss | Published result has brief grace, then clears correctly | NOT_RUN | |
| D18 | Quick movement between pairs | No stale/cross-pair result | NOT_RUN | |
| D19 | Mixed mass / volume | No winner | NOT_RUN | |
| D20 | Explicit different currencies | No winner | NOT_RUN | |
| D21 | VoiceOver result | Winner + A/B normalized prices understandable | NOT_RUN | |
| D22 | VoiceOver recovery states | Open Settings / Try Again discoverable and operable | NOT_RUN | |
| D23 | Larger Text | Critical result/recovery controls not clipped | NOT_RUN | |
| D24 | Reduce Motion | Candidate-frame animation disabled | NOT_RUN | |
| D25 | Contrast / non-color cue | Winner/result remains understandable without color | NOT_RUN | |
| D26 | Privacy runtime observation | No unexpected network/storage behavior in core flow | NOT_RUN | |
| D27 | Timing | Useful result <= 1.5 s after both tags stably readable | NOT_RUN | |

## Blocking failures

Any of these blocks the Validation milestone:

- wrong winner or unit price;
- price from one tag paired with quantity from another;
- 3+ tags producing an automatic pair;
- unit-price reference treated as package price;
- A/B overlay on wrong label;
- stale result after background/pair change;
- unrecoverable camera permission/scanner state;
- inaccessible critical recovery/result path;
- unexpected data persistence/network flow;
- crash/frozen camera;
- repeated stable-read timing above the agreed target.

Visual polish that does not change interpretation or accessibility of the core task is non-blocking for this first device pass.

## Historical user-validation result — candidate 8450963d

Evidence source: user-reported physical iPhone run and screenshot in the active ChatGPT session.

| ID | Scenario | Status | Evidence / issue |
| --- | --- | --- | --- |
| D01 | Local signed install | PASS | App launched on the physical iPhone. |
| D28 | First-use camera UX clarity | FAIL | Camera screen looked like an engineering prototype: large black areas, oversized dashed ROI and instruction card, no glanceable 0/2 → 1/2 → 2/2 recognition state. |

D28 is treated as blocking for the current Validation milestone because it affects comprehension of the core workflow, not merely decorative polish.

The PASS above remains historical Evidence for `8450963d` only.

## Historical user-validation result — candidate a2d9d9e0

Evidence source: user-reported physical iPhone run and screenshot in the active ChatGPT session.

| ID | Scenario | Status | Evidence / issue |
| --- | --- | --- | --- |
| D01 | Local signed install | PASS | New UI candidate launched on the physical iPhone. |
| D28 | First-use camera UX clarity | FAIL | User still could not understand what to do or where to act. |
| D29 | More than two products | FAIL | Fixed 0/2 workflow cannot support the requested 3+ item use case. |

D28/D29 are blocking and trigger a product-workflow change.

## Required retest for sequential multi-item workflow

| ID | Scenario | Expected | Status | Evidence / issue |
| --- | --- | --- | --- | --- |
| M01 | First-use instruction | User understands: scan one label → Add → scan next | NOT_RUN | |
| M02 | Stable recognition preview | Parsed price, quantity and unit price visible before Add | NOT_RUN | |
| M03 | Deliberate Add | Recognition alone never adds; Add inserts exactly one item | NOT_RUN | |
| M04 | Add second item | Tray shows both; best unit price is highlighted | NOT_RUN | |
| M05 | Add third item | All three remain; best updates across full set | NOT_RUN | |
| M06 | Add fourth+ item | Tray remains usable and horizontally scrollable | NOT_RUN | |
| M07 | Remove one item | Correct item disappears and best recomputes | NOT_RUN | |
| M08 | Clear comparison | Set clears without restarting camera | NOT_RUN | |
| M09 | Duplicate candidate | Same semantic item is not added twice | NOT_RUN | |
| M10 | Multiple labels in ROI | Add is unavailable; user is asked to center one | NOT_RUN | |
| M11 | Incompatible dimension | Candidate is rejected; existing set/winner unchanged | NOT_RUN | |
| M12 | Different explicit currency | Candidate is rejected; existing set/winner unchanged | NOT_RUN | |
| M13 | Move between labels | Previous items remain intact while current preview changes | NOT_RUN | |
| M14 | Background / foreground | Comparison set survives ordinary background; current preview resets safely | NOT_RUN | |
| M15 | VoiceOver | Add, remove, clear, best item and recognized values are understandable | NOT_RUN | |

## Historical physical OCR result — candidate d33616b9

Evidence source: user-reported physical iPhone run and screenshot in the active ChatGPT session.

| ID | Scenario | Status | Evidence / issue |
| --- | --- | --- | --- |
| D01 | Local signed install | PASS | Multi-item candidate launched on physical iPhone. |
| M01 | First-use single-label instruction | PASS / PARTIAL | Screen clearly asks to scan one label, but no recognition result appeared. |
| M02 | Stable recognition preview | FAIL | Real Russian promotional shelf label stayed at "Scan a price label"; no candidate preview / Add state. |
| R01 | Russian ₽ split-price label | FAIL | Label contained prominent 229 + 99₽, old 269 + 99, 200Г, discount text; app returned no parsed candidate. |

R01 is blocking.

## Required retest after RUB/language-hint fix

| ID | Scenario | Expected | Status | Evidence / issue |
| --- | --- | --- | --- | --- |
| R02 | Same Russian shelf label | Current price 229.99 ₽ + 200 g reaches Label ready | NOT_RUN | |
| R03 | OCR diagnostic state | If OCR text exists but parser still fails, UI shows Text found | NOT_RUN | |
| R04 | ₽ vs RUB | Same-currency comparison is accepted | NOT_RUN | |
| R05 | Old promotional price | Smaller old 269.99 does not beat prominent current 229.99 | NOT_RUN | |
