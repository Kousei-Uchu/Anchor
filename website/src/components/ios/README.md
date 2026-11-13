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
- The sample content (contacts, tasks, appointments, presets, recovery counter, affirmations and so on) comes from the app's own demo data.
  `scripts/sync-seed.mjs` reads `DemoMode.makeContainer` in `AnchorApp.swift` and writes `website/src/content/demo.seed.generated.json`.
  `website/src/content/seed.ts` turns that into what each card shows: the next appointment, the open tasks, the recovery counter and so on.
  Dates are worked out from today, so "In 4 days" stays correct. If the demo data changes in Swift, `check-all.sh` fails until you run `node scripts/sync-seed.mjs`.
- Mascot text and the rest of the older demo content still come from `demo.generated.json` (`scripts/sync-demo.mjs`).

## Looking at it

Run `cd website && npm run dev` and open `/demo-now`. Add `?dark` for dark mode. The route exists only in dev.

## What the Now preview covers

The whole Now tab, in the order `NowView.swift` lays it out: Crisis numbers, mascot, Check in, Quick contact, Recovery, Next appointment,
safety plan row, Decision presets, Grounding tools, Tasks, De-escalation script, Something to hold onto, and the tab bar.
The Sleep card is left out because the app only shows it when its setting is on, and the demo does not turn it on.
Quick contact names, tasks you tick off or add, "Try another" and "Another" all work.

Add `?full` to the address to lay the whole screen out without scrolling, and `?dark` for dark mode.
The older screenshot `website/public/shots/now.jpg` only shows the top of the tab as it was before the newer cards were added.

## Known differences from the app

- Icons are hand-drawn copies of the SF Symbols the app uses (SF Symbols cannot be used outside Apple platforms), so the shapes differ slightly.
- Rounded text uses `ui-rounded`, which only Safari has. Everywhere else it falls back to Nunito, which is close but not the same.
- Corners are circular, not iOS continuous corners.
- The tab bar is a plain frosted pill, not the system glass effect.
- The mascot in the app calls an `anchor` SF Symbol that does not appear on screen, so the website mascot has no anchor mark either.
- The crisis numbers are fixed for Australia, as in the app's demo.
- Tapping a card does not open its detail screen yet. Only the other four tabs and their detail screens are still to build.
