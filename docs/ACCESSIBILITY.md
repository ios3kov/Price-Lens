# Accessibility Validation — Price Lens

Baseline: AS Development Rules 4.1.0 @ `6a19ab6d44b34376edccda3515f1355d0ead2041`

## Implemented baseline

- SwiftUI semantic text styles are used for the main status/result UI.
- The winner is not indicated by color alone; text and symbol cues are present.
- The final result exposes the winner as an accessibility label and both normalized A/B unit prices as its accessibility value.
- The visual A/B tracking overlay is hidden from VoiceOver because it is camera geometry, not an actionable control.
- Candidate-frame motion is disabled when Reduce Motion is enabled.
- Camera-denied and scanner-failed states expose labeled recovery buttons.

## Physical-device checks for Validation

NOT_RUN until the validation build is installed on a physical iPhone:

- VoiceOver: open app, understand searching/one-tag/too-many/comparing/result/error states, activate Open Settings / Try Again.
- VoiceOver result: winner and both A/B normalized unit prices are understandable.
- Larger Text: status/result/recovery UI remains readable without clipped critical actions.
- Reduce Motion: A/B frame changes do not animate.
- Contrast: guidance/result/recovery text is readable over the camera surface.
- Core result does not rely on color alone.

Extended localization and App Store accessibility metadata are Release-scope work unless product scope changes.
