# Physical iPhone Validation — Price Lens

This is the first runtime gate after internal CI. It does not authorize merge or release.

## Target

- Branch: `feat/initial-mvp`
- Device class: iPhone 12 or newer supported iPhone
- Minimum OS: iOS 17
- Product workflow: camera -> two tags -> OCR -> normalized unit price -> A/B result

## Install from Xcode

1. Pull the exact commit recorded in `docs/STATUS.md`.
2. Open `PriceLens.xcodeproj`.
3. Select the `PriceLens` target -> Signing & Capabilities -> choose the developer Team if Xcode has not already done so.
4. Connect the iPhone, select it as the run destination, and Run the `PriceLens` scheme.
5. Record the installed commit before testing:

   ```bash
   git rev-parse HEAD
   xcodebuild -version
   ```

Do not call a build validated if the installed app came from a different commit than the evidence record.

## Controlled camera fixtures first

Open `validation/price-tag-fixtures.html` on the Mac, maximize the browser, and scan the displayed labels with the iPhone.

For each case:

- keep only the intended labels inside Price Lens' dashed comparison frame;
- wait for A/B overlays and the result;
- reveal the expected answer only after observing the app result;
- record PASS / FAIL;
- on any wrong winner, wrong quantity, wrong unit price, A/B mismatch or false comparison, stop and capture a screenshot/video.

## Physical shelf checks second

After the controlled fixtures pass, test real shelf labels:

- two labels side-by-side;
- two labels vertically stacked;
- small print;
- glare;
- angled camera;
- quick camera movement;
- temporary loss of one OCR line;
- tag containing both package price and per-kg/per-100g price;
- different package sizes;
- multipacks;
- count-based goods.

## Lifecycle checks

- first camera permission grant;
- deny camera -> Open Settings -> grant -> return without restarting;
- background the app while a result is visible -> return: old result must be gone;
- temporary scanner failure -> Try Again recovers without app restart.

## Blocking failures

The validation milestone is blocked by any of these:

- wrong winner;
- wrong unit normalization;
- price from one label paired with quantity from another;
- 3+ labels causing an automatic pair selection;
- unit price (`/kg`, `per 100 g`, etc.) treated as package price;
- stale result after background/foreground;
- A/B frame points to the wrong label;
- crash, frozen camera or unrecoverable permission state.

Visual polish that does not change interpretation is non-blocking for the first runtime pass.

## Evidence record

Record:

- commit SHA;
- Xcode version;
- iOS version;
- iPhone model;
- date;
- controlled fixture results;
- real-shelf results;
- screenshots/video for failures;
- observed time from stable framing to final comparison.

Target: useful result within 1.5 seconds after both labels are stably readable.
