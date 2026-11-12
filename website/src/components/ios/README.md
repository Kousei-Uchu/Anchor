# Website copy of the app's design system

These files let the website draw the app's screens from real components instead of screenshots.

## How it fits together

- `scripts/sync-design.mjs` reads `Anchor.Theme` in `iOS/Anchor/Anchor/ContentView.swift` and writes
  `website/src/content/design.generated.json` and `website/src/styles/design.generated.css`.
  Colours (light and dark), corner radius and spacing come from there, so they follow the app automatically.
- `AnchorUI.tsx` and `anchor-ui.css` are hand-written copies of the shared Swift components: Card, SectionHeader,
  MenuRow, TileButtonLabel, TileRow, EmptyState and the two button styles. Sizes and font weights are copied from the Swift.
- The same script keeps a short fingerprint of each of those Swift components. If one changes, `scripts/check-all.sh`
  fails and names it. Update `AnchorUI.tsx` and `anchor-ui.css` to match, then run `node scripts/sync-design.mjs` once to accept it.
- Text for the screens comes from `demo.generated.json` (`scripts/sync-demo.mjs`).

## Looking at it

Run `cd website && npm run dev` and open `/demo-now`. Add `?dark` for dark mode. The route exists only in dev.

## Known differences from the app

- Icons are small line drawings in `AnchorUI.tsx`. SF Symbols cannot be used outside Apple platforms.
- Rounded text uses `ui-rounded`, which only Apple browsers have. Other browsers fall back to the system font.
- Corners are circular, not iOS continuous corners.
- Real views read SwiftData and branch on it, so the preview uses made-up appointment, task and empty-state text.
- Only the Now tab has a preview so far.
