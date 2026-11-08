# Showcase mode

Point 17 of the plan: show someone the app without showing them your own content. It is in two patches. Patch 39 (this one) is the machinery. Patch 40 adds a passcode of its own, clears what could still show real things, and opens the switch to everyone. Until then it is only in test builds (Settings, Your data and help, Showcase mode (test build)).

## What it does while it is on

- **Made-up content.** The app runs on the in-memory demo store, the same one the screenshot tests use (`DemoMode.makeContainer`). It has one set of made-up content, so showcase mode, the screenshot tests and anything else that needs sample content all read the same thing. Nothing is written to disk.
- **The real store is not opened.** The setting is kept in the standard defaults, so it survives closing the app. A launch with showcase mode on never calls `AnchorSchema.makeContainer`, so the store file is not opened at all. (If the app was already running with the real store open when showcase mode was turned on, that store stays open in memory until the app closes, and is reused when showcase mode is turned off.)
- **The window is made again** when the mode changes, with a new identity (`ContainerHolder.generation`), so no screen, sheet or query is left holding something from the other store.
- **The app lock is not asked for.** `AppLock` treats showcase mode as the lock being off (when it starts, when the app comes back, and for the screens that ask again). The lock setting itself is not changed, so it applies again after showcase mode is turned off.
- **It counts as demo mode** for the things demo mode already leaves alone: Apple Health is never read or written, and no reminders are scheduled.

## Turning it on and off

- **On:** only on a phone that has Face ID, Touch ID or a passcode (`ShowcaseMode.canTurnOn`), so there is always a way back. It asks first.
- **Off:** asks for the phone's own Face ID or passcode, directly (`ShowcaseMode.confirmOwner`), not through Anchor's lock, which is not asked for while showcase mode is on. If it is not confirmed, showcase mode stays on.
- **Forgetting Anchor's own showcase passcode** is not a case yet, because there is none until Patch 40. The phone's authentication always works, and it will go on working after the passcode is added.

## Not done yet (Patch 40)

- A showcase passcode of its own, kept as a salted hash in the Keychain, as another way to turn it off.
- Clearing what could still show your real content outside the store: the widget summaries (the two sealed values from Patch 35a would be removed and the widgets reloaded), reminders that are already scheduled and their wording, the picture the phone takes of the app for the app switcher, and the share and export buttons.
- Opening the switch to everyone, in Settings, with its own screen and help.
- A way to put content in the demo that the screenshot tests do not need.

## Known gaps in this patch

- While it is on in a test build, the widgets still show your real contacts and counter, and reminders that were already scheduled still arrive. That is why it is test builds only.
- `DemoMode.makeContainer` falls back to the real store if an in-memory store cannot be made. That does not happen in practice, but a showcase that fell back would show real content. Patch 40 makes showcase mode stop instead.
- The JSON seed in the plan (one definition shared with the website demo) is not built. The seed is Swift code and the website demo is parked (Patches 49 and 50), so there is nothing to share it with yet.

## Checking a test build on a device

1. Settings, Your data and help, Showcase mode (test build). It says Off. Turn it on: the app should come back on Now with made-up content (Sam, Alex and Jordan as contacts, and so on), and nothing from your own store anywhere.
2. Close Anchor from the app switcher and open it again: it should still be in showcase mode, and go straight in without asking for Face ID.
3. Open Plan, Journal and Bridge and add something. It should be there until you close the app, and gone when you do.
4. Turn it off: it asks for Face ID or the passcode. Cancel it once: it should still be on. Then confirm: your own content should be back, and Anchor's lock should ask again the next time you leave and come back.
5. On a phone with no passcode, the switch should refuse and say why.
