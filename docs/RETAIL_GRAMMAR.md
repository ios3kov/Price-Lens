# Retail Grammar Contract — Price Lens

Baseline: AS Development Rules 4.1.0
Scope: OCR text normalization, price/quantity parsing and safe ambiguity handling.

## Goal

Price Lens must not depend on a finite list of shelf-label layouts.

The parser works on semantic classes:

1. numeric value;
2. currency;
3. package quantity;
4. unit;
5. multipack relation;
6. package-price vs reference-unit-price role;
7. current/prominent vs competing price geometry;
8. promotional/percentage noise;
9. OCR fragment geometry;
10. confidence / ambiguity.

A new retailer layout should normally be covered by an existing grammar class. New parser code is justified only when a genuinely new semantic class appears.

## Layer 1 — OCR text normalization

Before semantic parsing:

- Unicode compatibility normalization;
- non-breaking / thin spaces -> ordinary space;
- Unicode decimal digits -> ASCII digits;
- Arabic decimal separator -> dot;
- Arabic grouping separator -> comma;
- bidi direction marks removed;
- Unicode dash variants normalized;
- multiplication marks `×` / Cyrillic `х` normalized to `x`;
- package-price suffixes such as `р/шт.` normalized without turning `шт` into product quantity.

Raw OCR transcript remains available in ProductCandidate evidence.

## Layer 2 — currency grammar

Currency recognition is not limited to a hard-coded country list.

Sources:

- Foundation `Locale.Currency.isoCurrencies` for ISO currency codes;
- system `Locale.availableIdentifiers` + `currencySymbol` data for localized currency symbols;
- explicit high-value retail symbols/aliases for OCR stability;
- bounded retail aliases where OCR commonly emits words/abbreviations.

Symbols shared by multiple currencies (for example bare `$`, `¥`, `kr`) remain ambiguous instead of being silently mapped to one country.

Supported placement classes:

- symbol/code before amount: `€4.99`, `CHF 4.95`;
- symbol/code after amount: `4,99 EUR`;
- no space: `₹99`;
- separated OCR currency fragment;
- currency used in decimal position: `12€50`;
- retail per-package suffix: `56 99 р/шт.`;
- split whole/cents OCR: large `229` + small `99₽`.

Ambiguous symbols such as bare `$` are preserved as ambiguous tokens instead of being silently guessed as a specific national currency.

## Layer 3 — numeric grammar

Classes:

- comma decimal;
- dot decimal;
- one-, two- and currency-specific three-fraction prices;
- zero-cents forms `4,-`, `4.–`, `10:-`;
- grouped thousands with spaces / NBSP / narrow NBSP;
- dot/comma grouping;
- apostrophe grouping;
- Indian grouping;
- missing decimal separator with explicit currency;
- separate whole/cents OCR fragments;
- Arabic-Indic and other Unicode decimal digits;
- arbitrary integer prices for zero-decimal currencies.

Grouping and decimal interpretation follows structural position, not the user's phone locale.

## Layer 4 — quantity grammar

Base dimensions:

- mass -> kg;
- volume -> L;
- count -> item.

Aliases are data-driven in RetailLexicon.

Initial broad families include:

- metric mass: kg/g/mg and common Cyrillic/word/script aliases;
- imperial mass: lb/oz;
- metric volume: L/dL/cL/mL/µL/cc and script aliases;
- US/imperial volume: fl oz, pint, quart, gallon; GBP context selects imperial meaning for bare customary volume units;
- count: item/pc/pcs/ea/ct plus common European/Asian/Arabic count aliases;
- multipack forms: `6x330ml`, `6 × 330 ml`, `2х500г`.

Every alias maps to an explicit dimension + multiplier. Unknown units are not guessed.

## Layer 5 — role classification

Numbers are not automatically prices.

Reject / down-rank:

- discount percentages;
- reference unit prices across supported mass/volume units such as `/kg`, `/lb`, `/100 g`, `per kg`, `每公斤`;
- quantities used as prices;
- unrelated item/product codes;
- weak numeric fragments.

Retail per-package text such as `р/шт.` is explicitly distinguished from a reference unit-price line.

## Layer 6 — geometry and prominence

OCR geometry is part of the grammar.

Used to connect:

- whole price + cents;
- adjacent currency;
- price + package quantity;
- current prominent price vs smaller competing/old price;
- clusters of neighboring labels.

The parser may prefer a clearly more prominent price. It must not infer semantic eligibility such as loyalty-card membership merely from retailer layout.

## Layer 7 — ambiguity gate

Safety rule: **no guessed winner**.

If two materially different price/quantity interpretations are close enough in score, parsing returns no ProductCandidate.

Examples:

- two similar-size prices with different conditions;
- multiple quantities that could plausibly belong to the same price;
- multiple labels inside the single-label ROI;
- unsupported/unknown unit.

UI then stays in guidance / Text found state instead of adding a potentially wrong product.

## Layer 8 — extensibility

When a physical label fails:

1. capture OCR transcript + geometry, not just a photo;
2. classify whether failure is OCR, normalization, lexicon, role or geometry;
3. add a regression fixture reproducing the exact OCR output;
4. fix the lowest appropriate layer;
5. run the entire corpus;
6. preserve previous physical evidence;
7. retest the same label.

Do not add retailer-specific branches when the issue belongs to a general grammar class.

## Coverage strategy

We cannot prove support for every future shelf label in existence.

We can prove:

- broad grammar classes;
- a growing cross-region corpus;
- safe refusal on ambiguity;
- no regression across previously observed labels;
- diagnosable physical failures.

That is the product-level meaning of “handle arbitrary price labels”.
