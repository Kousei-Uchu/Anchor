# Android: the decision write-up (patch 54)

Written 12 Nov 2026. This is a write-up to decide from, not a commitment. Android stays "planned, far in the future" (D4); nothing in the Swift patches waits on it.

## 1. The short version

- **Today's app is much larger than the plan's old estimate.** Point 28 said about 14,000 lines. Counting the Swift files now gives 103 files and about 51,000 lines (this includes the widget and UI tests). Every effort figure below is scaled to that, not to 14,000.
- **A Swift to React Native move is a rewrite, not a port.** Only the design, content, data model and file formats carry over.
- **The file formats are the part that is already portable.** The recovery key, recovery file, sealed text, `.anchorbackup` and the plain JSON export are all written down byte by byte (`docs/ENCRYPTION.md`, `docs/BACKUP.md`, `docs/EXPORT.md`), with `scripts/anchorkey.py` as running reference code. An Android app could open an iOS backup without any change on the iOS side.
- **Recommendation:** finish iOS, then do a small spike (section 6) before choosing a route. Do not start a rewrite on the strength of a feeling. Decide with real demand: do people ask for it?

## 2. What the app uses from Apple, and what Android has

| iOS piece (where) | Android equivalent | Cost |
| --- | --- | --- |
| SwiftUI, 77 files | Jetpack Compose, or React Native | Full rewrite either way |
| SwiftData, 59 files (34 models) | Room, or SQLite in React Native | Rewrite; the model list is in `docs/FIELD_INVENTORY.md` |
| CryptoKit, CommonCrypto (6 files: AppLock, LockMyData, SafetyCopy, BridgeExport, DataControl, WidgetDataStore) | Android Keystore plus standard AES-GCM and HKDF libraries | Medium; the formats are specified, so it can be checked against the vectors |
| `SQLite` in `LockMyData.swift` | SQLCipher is available, so whole-database encryption becomes possible | Small to medium, and a real upside |
| LocalAuthentication (the app lock) | `BiometricPrompt` | Small |
| WidgetKit, ActivityKit (5 and 3 files) | Glance or AppWidget, native Kotlin only | Medium. Home-screen widgets are possible; there is no lock-screen widget or Live Activity equivalent, so the next-hour checklist needs a different design (an ongoing notification) |
| UserNotifications (5 files) | Notification channels, with the Android 13+ permission | Small to medium |
| MessageUI (4 files: the "send a message" actions) | SMS and share intents | Small |
| ContactsUI | Contact picker intent | Small |
| PencilKit (journal drawings) | A custom canvas | Medium |
| Charts (Journal) | A chart library | Small |
| The mascot, drawn in SwiftUI shapes | Rebuild in Compose Canvas or `react-native-svg` | Medium |
| Speech (dictation) | Android `SpeechRecognizer` | Small to medium |
| FluidAudio and CoreML (speaker separation, 26 model files, about 21.6 MB) | Needs a different runtime for the same models, or the feature is dropped on Android | Large. Treat as optional |
| FoundationModels (Apple's on-device model) | No equivalent. The other AI providers (a local Ollama address, or one the person adds) could still work | Feature differs by platform |
| CloudKit (`FileSync.swift`) | No equivalent. Sync would need a different design, and it must stay optional and off by default | Large; probably not in a first Android release |
| HealthKit (sleep import) | Health Connect | Medium |
| EventKit (Reminders, calendar) | Calendar provider; there is no Reminders app equivalent | Reduce or drop |
| JournalingSuggestions, MusicKit | iOS only | Drop. The Journal works without them |
| Photos | The photo picker | Small |
| CoreImage (recovery key QR code) | A QR library | Small |

Features that would not exist on Android as they are: Journaling Suggestions, the lock-screen widget and Live Activity, Reminders import, Apple's on-device model, and iCloud sync. That is a real difference in what the app is, and it should be said openly on the Android page.

## 3. Three routes

| Route | What it is | For | Against |
| --- | --- | --- | --- |
| **A. Native Kotlin and Compose** | A second app, written separately | The best widgets, notifications and lock integration; no JavaScript layer between the app and the private data | Two codebases to keep in step, by one person |
| **B. React Native (Expo), a full move** | Rewrite everything in TypeScript; one codebase for iOS, Android and the web demo | One place to change things; the web demo (55) falls out of it; SQLCipher works | Rewrites about 51,000 lines of working Swift. Widgets, Live Activities, biometrics, Journaling Suggestions and Reminders still need native code per platform. A big risk to the working iOS app |
| **C. Share only the data, not the code** | Keep the Swift app. Share the specs, test vectors, guide content, check-in prompts and demo seed as plain data. Build Android later (route A) against the same specs | Least risk to iOS; the portability work is already being done (field inventory, format specs, shared guide data) | Android still costs a full build whenever it happens |

Route C is the one the project is already following without naming it. Route B is the only one that also solves the web demo, and it is by far the largest.

## 4. Google Play, so there are no surprises

- **A new personal developer account must run a closed test first.** Google's help page says accounts created after 13 November 2023 need at least 12 testers opted in continuously for at least 14 days before applying for production access. A tester who opts out and back in restarts their 14 days.
- **For Anchor this means finding 12 people.** That is hard for a privacy-first app with no accounts and no analytics, and it should be planned for well ahead (friends, family, the people who already encouraged the project).
- **Not checked here:** Google's developer verification requirements and any registration fee. Look at the current Play Console pages before relying on this section.
- **Policy work, not code:** the Data Safety form, and a decision about Android's `allowBackup`, which must match the privacy page's promises (no copies of private data leave the device unless the person chooses).

## 5. What to do now on iOS so Android is cheaper later

These are small and mostly already the habit:

1. Keep every format specified and tested (recovery key, backup, export). Add Android-readable vectors whenever a format changes.
2. Keep content as plain data (guide registry, check-in prompts and starters, quantity rules, demo seed), as the plan's keep-it-portable rule already says.
3. Keep optional, Apple-only features optional and off by default, and keep their wording honest about being iOS-only.
4. Do not add a new Apple-only dependency to a core feature (anything the safety plan, check-in or Journal needs to work) without a note in this file.

## 6. The optional spike (small, and only if wanted)

A one-day test that settles the biggest unknown, without committing to a route:

- Open a real `.anchorbackup` and a recovery file on Android using plain Kotlin or a small script, and check it against the vectors from `scripts/anchorkey.py`.
- Draw the mascot and one screen (the check-in) in Compose, to see how much of the look carries over.
- Record how long each took and how much was missing.

If the first goes cleanly, a native Android app that restores iOS backups is realistic. If the second feels wrong, that is the argument for route B instead.

## 7. Questions only you can answer

1. Is Android wanted because people have asked, or because it feels like the right size for the project? (This decides whether to start at all.)
2. If it comes, is it acceptable that it is a smaller app (no lock-screen widget, no iCloud sync, no Apple model, no speaker separation at first)?
3. Is one codebase worth a rewrite of the iOS app, or is two apps sharing specs acceptable? (Route B against routes A and C.)
4. Who would the 12 closed testers be?

## 8. Recommendation

Route C now, a spike when iOS is steady, and the route A or B decision after the spike and after seeing real demand. Keep D4 as it is: planned, far in the future.
