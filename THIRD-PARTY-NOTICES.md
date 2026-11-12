# Anchor Third-Party Notices

Last audited: 11 November 2026.

Anchor's own code and assets are covered by Anchor's own terms. Everything
listed here belongs to someone else and stays under its own licence, which
Anchor's licence does not change.

## What was audited, and what was not

Audited against the files in this repository:

- The Swift packages the iOS project resolves (`Package.resolved`).
- The model files bundled in the app (`iOS/Anchor/Anchor/DiarizerModels/`).
- The direct dependencies of the website (`website/package.json`) and of the
  promo video (`remotion-project/package.json`).
- The images, sound and video files in `website/public/` and
  `remotion-project/public/`, and the app icon art.

Not audited:

- Packages that the website and promo video's direct dependencies themselves
  depend on (the transitive npm tree).
- Inline icons and small graphics written directly into the website's source.

`scripts/check-third-party.mjs` fails when a direct dependency, a Swift package
version, the model commit or a sound file is missing from this file, so this
list cannot quietly fall behind. It cannot judge whether a licence is correct.

## In the iOS app

| Component | Version | Licence | Source | Notes |
|---|---|---|---|---|
| FluidAudio | 0.18.3 | Apache-2.0 | https://github.com/FluidInference/FluidAudio | Swift package, linked into the app and used only by `Support/SpeakerSeparation.swift`. Apache-2.0 asks that its licence text and notices stay with copies you redistribute. |
| Speaker-separation models: `Segmentation`, `FBank`, `Embedding`, `PldaRho` and `plda-parameters.json` | commit `7eab74f3463c736418d0eb10296261ae581146c9` of `FluidInference/speaker-diarization-coreml` | CC-BY-4.0 | https://huggingface.co/FluidInference/speaker-diarization-coreml | Core ML conversions, made by Fluid Inference, of the pyannote `speaker-diarization-community-1` pipeline and of the PLDA files from BUT Speech@FIT; the embedding model is WeSpeaker ResNet34. They are modified (converted) copies. The licence text and the notice that CC-BY-4.0 asks to be kept are in `iOS/Anchor/Anchor/DiarizerModels/LICENSE` and `NOTICE.md`. About credits them. |
| Apple system components | the iOS SDK in use | Apple's terms | https://developer.apple.com | SF Symbols (used by name through the system, not copied into this repository), the system fonts, SwiftUI, SwiftData, CloudKit, WidgetKit and other frameworks. Apple's developer terms apply to them. |

## In the website (`website/`)

| Component | Version | Licence | Source | Notes |
|---|---|---|---|---|
| @fontsource/inter | ^5.3.0 | OFL-1.1 | https://fontsource.org | The Inter typeface, bundled into the site. The SIL Open Font Licence asks that its copyright and licence notice travel with the font files. |
| @fontsource-variable/fraunces | ^5.3.0 | OFL-1.1 | https://fontsource.org | The Fraunces typeface, bundled into the site. Same condition as Inter. |
| @fontsource-variable/nunito | ^5.3.0 | OFL-1.1 | https://fontsource.org | The Nunito typeface, bundled into the site as the rounded text fallback in the demo for browsers without Apple's rounded system font. Same condition as Inter. |
| react | ^19.3.1 | MIT | https://react.dev | |
| react-dom | ^19.3.1 | MIT | https://react.dev | |
| react-router-dom | ^7.18.5 | MIT | https://reactrouter.com | |
| motion | ^14.9.1 | MIT | https://motion.dev | |
| remotion | 4.0.540 | Remotion License (not open source) | https://www.remotion.dev | See the Remotion note below. |
| @remotion/player | 4.0.540 | Remotion License (not open source) | https://www.remotion.dev | Shipped inside the website's bundle. See the Remotion note below. |
| vite | ^8.3.5 | MIT | https://vite.dev | Build tool, not shipped. |
| @vitejs/plugin-react | ^6.2.1 | MIT | https://github.com/vitejs/vite-plugin-react | Build tool, not shipped. |
| typescript | ^7.0.2 | Apache-2.0 | https://www.typescriptlang.org | Build tool, not shipped. |
| @types/react | ^19.0.0 | MIT | https://github.com/DefinitelyTyped/DefinitelyTyped | Type definitions, not shipped. |
| @types/react-dom | ^19.0.0 | MIT | https://github.com/DefinitelyTyped/DefinitelyTyped | Type definitions, not shipped. |

## In the promo video (`remotion-project/`)

| Component | Version | Licence | Source | Notes |
|---|---|---|---|---|
| remotion | ^4.0.540 | Remotion License (not open source) | https://www.remotion.dev | See the Remotion note below. |
| @remotion/cli | ^4.0.540 | Remotion License (not open source) | https://www.remotion.dev | Used to render the video. Not shipped. |
| @remotion/transitions | ^4.0.540 | Remotion License (not open source) | https://www.remotion.dev | npm lists this package's licence as `UNLICENSED`. It is published by Remotion and is treated here as covered by the Remotion License; this has not been confirmed with them. |
| react, react-dom | ^18.3.1 | MIT | https://react.dev | |
| @types/react | ^18.3.31 | MIT | https://github.com/DefinitelyTyped/DefinitelyTyped | Type definitions, not shipped. |
| typescript | ^7.0.2 | Apache-2.0 | https://www.typescriptlang.org | Build tool, not shipped. |

### Remotion note

Remotion is source-available, not open source. Its free licence covers
individuals, for-profit organisations with up to three employees, and
non-profit or not-for-profit organisations. A larger for-profit company needs
a paid Company License from Remotion. The Remotion License is at
https://github.com/remotion-dev/remotion/blob/main/LICENSE.md.

This matters to anyone who forks the website or the promo video: Anchor's
licence does not grant Remotion rights, and Remotion's terms follow the
Remotion code into a fork.

## Assets

| Asset | Creator | Licence | Source | Attribution |
|---|---|---|---|---|
| App icon art: `iOS/Anchor/Anchor/AppIcon.icon/Assets/face.png` and `body.png` | Kousei Uchu | Project-owned, under Anchor's own terms | Made for this project | None needed |
| The mascot | Kousei Uchu | Project-owned, under Anchor's own terms | Drawn in SwiftUI shapes in the app's source | None needed |
| Screenshots and demo video: `website/public/shots/`, `website/public/assets/media/`, `remotion-project/public/shots/`, `website/public/assets/icon.png`, `remotion-project/public/icon.png` | Kousei Uchu | Project-owned, under Anchor's own terms | Made with the app's showcase mode, which uses made-up content | None needed |
| Ambient sound: `remotion-project/public/ambient.wav`, and `website/public/ambient.mp3`, which is the same sound encoded smaller | Synthesised by `remotion-project/scripts/make-audio.py` from the notes in `remotion-project/src/music.json`. Script and notes written by Claude (Anthropic), as stated by Kousei Uchu | FA-L, as stated by Kousei Uchu | No recorded or sampled material, and no outside source | **Open:** the text of the FA-L licence is not in this repository yet. Add it, or replace this line with a plain public-domain dedication, before a public release. |

## Review requirements

Before a public release:

- Add the FA-L licence text, or replace it (see Assets above).
- Audit the transitive npm packages, or record that they are covered by the
  same checks as their parents.
- Keep this file in step with `Package.resolved`, both `package.json` files,
  the bundled model files and the sound and image files; the check script
  catches most drift.
- Update this file whenever a dependency or asset is added, removed or
  changes licence.
