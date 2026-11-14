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
- `scripts/sync-widgets.mjs` reads the widget table the Plan, Bridge and Thread tabs are built from (`WidgetID` and `WidgetTab` in
  `Views/Widgets`) into `website/src/content/widgets.generated.json`: each widget's title, icon and tint, which ones pair two to a row,
  the default order, and which are hidden by default (Sleep, so it sits under "More").
- `scripts/sync-seed.mjs` also expands helper calls the demo uses, such as `SafetyPlanSections.makeSections(...)`, by reading the helper's
  definition from the Swift.
- `IosApp.tsx` is the app shell: the status bar, help and settings buttons, large title and a tab bar that switches between the tabs in `tabs/`.
  `cards.tsx` holds the cards the Now tab and the Plan widgets share.
- Mascot text and the rest of the older demo content still come from `demo.generated.json` (`scripts/sync-demo.mjs`).

## Looking at it

Run `cd website && npm run dev` and open `/demo-now`. Add `?dark` for dark mode. The route exists only in dev.

## What is built

- **Now**: the whole tab, in the order `NowView.swift` lays it out. The Sleep card is left out because the app only shows it when its
  setting is on, and the demo does not turn it on.
- **Plan**: the widget layout from `PlanView.swift`, with half-width widgets paired, the "More" row and the Customise button.
- **Journal**: the Days timeline from `JournalView.swift`: day badges, entries with their recovery-day chips, check-ins with their five bars,
  bookmarks, search, and the title, search and Days / Month / Year control pinned while the entries scroll. Month and Year are not rebuilt yet.
- **Bridge** and **Thread**: their widget layouts, laid out by the same `WidgetStackView` as Plan. Things to raise has tickable rows, Next session has its two
  buttons, and Thread has the message log, the support calendar week strip, People, To future me, Things I haven't said and Boundaries.
- On tabs where the whole page scrolls (Now, Plan, Bridge, Thread), the large title collapses into a centred inline title as it does in the app.
- Tapping a card does not open its detail screen yet.
- Dates in the demo are worked out from a fixed "now" of 10:25 am on today's date (`demoNow` in `seed.ts`), which is the time of day the app's
  demo data is built around, so every visitor sees the same day grouping whatever their time zone.

Open `/demo-now` in `npm run dev`. Add `?tab=plan` (or journal, bridge, thread) to open a tab, `?full` to lay the whole screen out without scrolling,
and `?dark` for dark mode. Names, tasks you tick off or add, "Try another" and "Another" all work.

## Comparing against the app

`scripts/save-reference-shots.sh` (Mac with Xcode) records every screen of the real app into `reference-shots/` at 660 pixels wide,
with a `.json` beside each listing its buttons. Compare a rebuilt screen against `reference-shots/<name>.jpg`.
The older `website/public/shots/now.jpg` only shows the top of the Now tab as it was before the newer cards were added.

## Known differences from the app

- Icons are hand-drawn copies of the SF Symbols the app uses (SF Symbols cannot be used outside Apple platforms), so the shapes differ slightly.
- Rounded text uses `ui-rounded`, which only Safari has. Everywhere else it falls back to Nunito, which is close but not the same.
- Corners are circular, not iOS continuous corners.
- The tab bar is a plain frosted pill, not the system glass effect.
- The mascot in the app calls an `anchor` SF Symbol that does not appear on screen, so the website mascot has no anchor mark either.
- The crisis numbers are fixed for Australia, as in the app's demo.
