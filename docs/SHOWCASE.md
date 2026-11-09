# Showcase mode

Point 17 of the plan: show someone the app without showing them your own content. It came in three steps. Patch 39 is the machinery. Patch 40a clears what lives outside the store and leaves out the share and export controls. Patch 40b (the last) adds a passcode of its own and an exit flow, and opens the switch to everyone in Settings, Your data and help, Showcase mode.

## What it does while it is on

- **Made-up content.** The app runs on the in-memory demo store, the same one the screenshot tests use (`DemoMode.makeContainer`). It has one set of made-up content, so showcase mode, the screenshot tests and anything else that needs sample content all read the same thing. Nothing is written to disk.
- **The real store is not opened.** The setting is kept in the standard defaults, so it survives closing the app. A launch with showcase mode on never calls `AnchorSchema.makeContainer`, so the store file is not opened at all. (If the app was already running with the real store open when showcase mode was turned on, that store stays open in memory until the app closes, and is reused when showcase mode is turned off.)
- **The window is made again** when the mode changes, with a new identity (`ContainerHolder.generation`), so no screen, sheet or query is left holding something from the other store.
- **The app lock is not asked for.** `AppLock` treats showcase mode as the lock being off (when it starts, when the app comes back, and for the screens that ask again). The lock setting itself is not changed, so it applies again after showcase mode is turned off.
- **It counts as demo mode** for the things demo mode already leaves alone: no reminders are scheduled and no permission question is asked.

## What 40a adds: the sweep

`ShowcaseSweep` (in `AnchorApp.swift`) takes things off the phone when showcase mode starts and puts them back when it stops.

- **Widgets.** The contact and plan summary and the Recovery counters, which the lock screen and home screen show, are removed and the widgets reload, so they show their empty state. While showcase mode is on nothing writes them again (Plan's refresh and the Recovery widget sync do nothing). They are empty, not filled with made-up content, on purpose: the widgets are part of how someone reaches help, and a made-up phone number there would be worse than none.
- **Reminders.** Every pending and every delivered notification is removed, because the trigger window reminders carry your window's label and a line from your own safety plan inside them. While showcase mode is on the schedulers do nothing, so a trigger window or a daily check-in made in the showcase does not put a real reminder on the phone.
- **Putting it back.** When showcase mode is turned off, `ShowcaseSweep.end` rebuilds the widget summary from the real store (the same fields Plan writes), refreshes the Recovery reminders and counter widget, the routine reminders, the sleep reminder, the trigger window reminders and the daily check-in, and reloads the widgets. Nothing waits for Plan to be opened.
- **A launch that started in showcase mode** skips the one-time steps a normal launch runs on the real store (locking an old plain widget copy, moving the old Next hour list into tasks, copying the safety plan into sections). They now run when showcase mode is turned off and the real store is opened for the first time, so the plan is there straight away and not after the next launch.
- **Fails closed.** If the made-up store cannot be made, turning showcase mode on does nothing and says so. On a launch that was already in showcase mode, showcase mode turns itself off and the real store opens behind Anchor's own lock, as on any other launch. It never shows the real store as if it were the showcase.
- **Share and export.** Controls that open the system share sheet are left out while it is on: Share on a Recovery counter, Share as picture or PDF on a diagram, the Boundaries share button, Share with on the support calendar, Share voice note, and the export button on Bridge and on Bridge draft. The share sheet lists the phone's own people and recent contacts. On Your data, Export, Import and Clear all data are replaced by one line saying they are switched off; Clear all data in particular would reach outside the store (photo files, Apple Health samples, the widget key).
- **Apple Health.** The Apple Health card on the Sleep screen is hidden, so nothing there can disconnect Health or remove what Anchor saved.
- **App switcher.** While the app is not the one in front, a plain screen is laid over the main window, so the app switcher does not show whichever made-up page was open. It does not cover a sheet that is open.

## Turning it on and off

- **On:** only on a phone that has Face ID, Touch ID or a passcode (`ShowcaseMode.canTurnOn`), so there is always a way back. It asks first, and says that the widgets and reminders are cleared.
- **Off:** asks for the phone's own Face ID or passcode, directly (`ShowcaseMode.confirmOwner`), not through Anchor's lock, which is not asked for while showcase mode is on. If it is not confirmed, showcase mode stays on.
- **Forgetting the showcase passcode** never locks anyone in. The phone's own Face ID or passcode always turns showcase mode off, with or without a showcase passcode.

## What 40b adds

- **A switch for everyone.** Settings, Your data and help, Showcase mode is no longer a test-build screen. It has its own screen with a "?" help sheet (`ShowcaseHelp`, shown by `HelpNoteSheet`). While showcase mode is on, that screen only offers to turn it off.
- **A showcase passcode of its own** (`ShowcasePasscode`, in `AppLock.swift`). Optional, at least four characters, typed twice. Only a salted PBKDF2-SHA256 hash is kept (200,000 rounds, 16-byte salt), never the passcode, in the Keychain with the same protection class as the data key (after first unlock, this device only). It reuses `BackupFormat.deriveKey`, so there is one key-derivation routine. Turning showcase mode on without one is allowed: the confirmation says that only the phone's Face ID or passcode will turn it off, and offers Set a passcode first.
- **Changing or removing the passcode** asks for the phone's own Face ID or passcode first, so someone holding the phone in a showcase cannot swap it. Those two buttons only show while showcase mode is off.
- **The exit flow** (`ShowcaseExitView`, a sheet): the showcase passcode if one is set, and always Use Face ID or the phone's passcode (`ShowcaseMode.confirmOwner`, asked directly, not through Anchor's lock).
- **Slowing down guesses.** After four wrong tries in a row the fifth starts a wait of 30 seconds, and each wrong try after that doubles it, up to 15 minutes. The wait only applies to the showcase passcode, never to the phone's own Face ID or passcode, so it cannot lock anyone in. A right passcode, or setting or removing the passcode, clears the count. The count is kept in the standard defaults.
- **Clear all data** also removes the showcase passcode (it is a stored secret). It is switched off while showcase mode is on, so it cannot be used to remove the passcode from inside a showcase.
- **The privacy page** has a Showcase mode section and a new effective date (8 November 2026).

## What the made-up content covers (RV7)

The demo store is one function, `DemoMode.makeContainer` in `AnchorApp.swift`, with a helper for Recovery under it. Patch RV7 went through every kind of content the app keeps (the 34 models in `AnchorSchema.models`) and filled the ones that were empty, so no screen in a showcase is bare. What was missing before: trigger windows, unsent drafts, the choices inside the decision presets (the three categories were there but empty), the de-escalation scripts, and all of Recovery. Thin ones were widened: two more people with pages of their own, earlier sessions with notes, a message log for each person, twelve journal days across eight weeks with one favourite, six check-ins, two weeks of sleep, and a second routine.

- **Plan and Now:** three people (Sam, Alex and Jordan, each with notes), a four-section safety plan, five grounding tools, three trigger windows (one switched off), three de-escalation scripts, four affirmations, decision presets with options in all three categories (one option of each kind with steps), tasks with steps and a blocked task, a quick list and an archived one, two routines, a packing list.
- **Journal and Sleep:** twelve journal days across eight weeks (so the month and year views have dots in more than one month), a favourite, notes written around the earlier sessions, six check-ins with different sliders, fourteen nights of sleep, a goal with the SMART frame on and a reached one.
- **Bridge:** two clinicians, an upcoming session each, earlier sessions with prep and after-session notes (one marked as moved), four things to raise (one answered), three diagrams.
- **Thread:** messages to each of the three people, three support calendar days (one past), two future notes (one a letter for a hard night), three unsent drafts (one already sent), the boundaries list and two message starters.
- **Recovery:** one counter, Energy drinks, with a run that ended and a fresh one, so the streaks, the calendar and the list of times all have something to show. It has savings, four motivations, four days of entries (one with a slip, two with a pledge and a review), and four urges. It was picked to be plain and not heavy: showcase mode is for showing the app to someone else. A review run adds two short counters of its own on top (see `ReviewSeed`).

Left out on purpose: the older safety plan form and the older Next hour list (both moved into newer models and no longer shown), and the mascot's lines (seeded by the app itself on the first Now screen). Voice notes and photos are files, not store content, so the demo has none; the screens that list them show their empty state. A grounding tool that opens another app is not made up either, because the link would open a real app on the phone.

**Keeping it complete.** `node scripts/check-demo-coverage.mjs` reads `AnchorSchema.models` and fails if a model has no made-up content and is not on its short list of exceptions. Run it when a model is added. It only checks that content exists, not that there is plenty of it; that part is for a person to look at, with the review stop for RV7.

## Not done

- Voice notes and photos in the demo (see above).
- A guide entry for showcase mode. The guide registry (Patches 41 to 43) does not exist yet, so for now the "?" sheet on the screen is the help.

## Known gaps

- Settings that are stored as settings (reminder times, switches, layout) are not swapped or hidden. They are not content, and a change made while showcase mode is on stays.
- The widgets are empty while it is on (see above).
- The Encryption test screen in a debug build can still remove the real data key. It is test-build only and goes before release.
- The JSON seed in the plan (one definition shared with the website demo) is not built. The seed is Swift code and the website demo is parked (Patches 49 and 50), so there is nothing to share it with yet.

## Checking a test build on a device

Before you start, have a real contact and a real trigger window set up, with the widgets on your home screen, and set the trigger window to start a few minutes ahead.

1. Settings, Your data and help, Showcase mode (test build). It says Off. Turn it on. The dialog should say the widgets and reminders will be cleared. The app should come back on Now with made-up content (Sam, Alex and Jordan as contacts, and so on).
2. The widgets should go to their empty state within a few seconds. The trigger window reminder should not arrive. Settings, Notifications, Anchor should show nothing waiting if your phone lists it.
3. Open Plan, Journal and Bridge and add something. It should be there until you close the app, and gone when you do. Open Your data: Export, Import and Clear all data should be replaced by one line. Look for share buttons on Bridge, Boundaries, a Recovery counter and a diagram: they should not be there. Open the Sleep screen: no Apple Health card.
4. Press the home button and open the app switcher: Anchor should show a plain screen.
5. Close Anchor from the app switcher and open it again: it should still be in showcase mode and go straight in without asking for Face ID.
6. Turn it off: it asks for Face ID or the passcode. Cancel it once: it should still be on. Then confirm: your own content should be back, the widgets should fill in again within a few seconds with your contact and counters, and the trigger window reminder should be scheduled again (move its time a few minutes ahead and wait for it).
7. Do 5 and 6 starting from a cold launch in showcase mode (turn it on, force close, open, turn it off): the Safety plan should have its sections straight away.
8. On a phone with no passcode, the switch should refuse and say why.

Checks for 40b (it is in release builds now, so use any build):

9. Settings, Your data and help, Showcase mode is there, without "(test build)". The "?" opens a sheet that scrolls and ends with Got it.
10. Set a passcode (Set a passcode, typed twice). Try a different second entry and one under four characters: each should say so and not save. Then set it properly. The screen should now say Set, with Change passcode and Remove passcode.
11. Change passcode and Remove passcode should each ask for Face ID or the phone's passcode first. Cancel it: nothing should change and it should say so.
12. Turn on showcase mode. Open Settings, Showcase mode: it should only offer Turn off showcase mode. Tap it. Type a wrong passcode: it should say so and clear the field. Type the right one: your own content should come back, with the widgets and reminders as in step 6.
13. Do 12 again, this time with Use Face ID or the phone's passcode instead of the passcode. Cancel it once: showcase mode should still be on.
14. Type a wrong passcode five times in a row: the fifth should say to wait about 30 seconds. While it waits, the right passcode should say to wait as well, and Use Face ID or the phone's passcode should still work.
15. With no passcode set, turn on showcase mode: the dialog should say only the phone's Face ID or passcode will turn it off, and offer Set a passcode first. In the showcase, Turn off should offer only the phone's Face ID or passcode.
16. Set a passcode, then Your data, Clear all data (on a test copy, not your real data): afterwards Showcase mode should say Not set.
