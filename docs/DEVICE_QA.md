# Device QA — Price Lens Validation Candidate

Candidate source: `8450963dc1db139d2bed9e1b3fea3e0a3236ae06`
Baseline: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

All runtime results default to NOT_RUN until observed on the physical iPhone.

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

After production UI bytes change, D01/D28 and affected scanner/accessibility checks must be repeated on the new candidate. The PASS above remains historical Evidence for `8450963d` only.
