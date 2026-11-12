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

## What the Now preview covers

Status bar, help button, large title, Crisis numbers, mascot with speech bubble, Check in, Quick contact (tap a name to switch),
Next appointment, safety plan row, the Grounding tools card, and the floating tab bar. It was compared against
`website/public/shots/now.jpg` (the real app on a Pro Max) and lines up to within a couple of points.
The Tasks, De-escalation and Affirmations cards further down are not built yet.

## Known differences from the app

- Icons are hand-drawn copies of the SF Symbols the app uses (SF Symbols cannot be used outside Apple platforms), so the shapes differ slightly.
- Rounded text uses `ui-rounded`, which only Safari has. Everywhere else it falls back to Nunito, which is close but not the same.
- Corners are circular, not iOS continuous corners.
- The tab bar is a plain frosted pill, not the system glass effect.
- The mascot in the app calls an `anchor` SF Symbol that does not appear on screen, so the website mascot has no anchor mark either.
- The preview uses the values the app shows in demo mode for contacts, the appointment and the crisis numbers.
