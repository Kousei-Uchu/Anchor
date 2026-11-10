# Anchor: what is left

*Only what is still to do. When something is finished, confirmed or answered, it is deleted from this file in the same patch, never moved to a done list. Finished work is in the Progress table of `ANCHOR_PATCH_PLAN.md` and in `docs/PLAN_CHANGELOG.md`. Last updated: 10 Nov 2026, after AI7.*

## 1. Waiting on you

**Words and files**

- The words for the About screen's creator section (D23, 1).
- The licence files you said you would attach, so the `LICENSE` file can be written (D23, 2). Nothing is written yet.

**Things only you can try**

- D29a: try the Apple Health sleep cleanup on a real device (a review run never touches Health). The Apple Health checklist is in `docs/SLEEP.md`.
- D28: read the privacy page and open its links, before a TestFlight build.

## 2. Pushed, waiting for a build and a try on your phone

Quickest way to check many at once: `scripts/review-on-device.sh` (the numbered review bar, Patch R1). Each line is what to look at.

- RV1a: Task cards, the quiet line is now a few small facts that wrap instead of being cut off.
- 30p2: Settings, After-session reminders, a switch for each person, that evening or the next morning.
- 35d: Settings, Lock my data, Voice notes and photos (test builds only). Try on a copy of your data, with the safety copy first.
- AI1: Settings, AI tools: the consent sheet, where it runs, Don't ask again (test builds only until the first real tool).
- AI2: Make shorter in the Journal editor's three dots menu: Keep or Discard, folded original.
- AI3: Break into steps and Estimate time under a task's steps.
- AI4: Tidy a braindump from the Journal page's three dots, Add several on Tasks and the task helper.
- AI5: Settings, AI tools, On my computer: an address on your own network, a model name, Look for models.
- VN1: Settings, Journal, Dictate in the Journal, then the microphone on a Journal page.
- VN2: Settings, Journal, Keep a voice note while dictating.
- VN3: Label who is speaking while dictating, and Rename speakers.
- 35e: Settings now shows Encryption, Safety copy and Lock my data in every build. Open each from Settings and check the names; the Encryption guide page (the question mark) now opens. A new check on the website: Features should show an Encryption entry.
- AI7: with AI tools off (Settings, AI tools), a Journal page's three dots should show Tidy a braindump greyed and no Make shorter; Things to raise, Add several (after typing words) and a named task's steps should show the greyed buttons; tapping one should say AI tools are off and where to turn them on. Turn AI tools on and the real buttons should be back. A menu item may not look grey.
- 47: the website's Features and Philosophy pages.
- 48: the website's About page, the Support answers and the Privacy page.
- 51: the website's `/beta` page. Sign-ups stay closed until you change the flag in `website/src/content/beta.ts`, and the TestFlight link there is empty.

The website patches (47, 48, 51) were typechecked and built in a scratch copy only; no Swift changed in them.

## 3. Not started, in order

1. **AI8**: Ollama addresses off the home network, such as Tailscale or IPv6, accepted after a prompt and a confirmation (D56). Size S.
2. **AI9**: AI Optimised blocks in exports as two labelled entries when you tick them in (D43). Size S.
3. **AI6**: other AI provider as a plain setting: address, key (kept in the Keychain) and model in the OpenAI API format, off and empty to begin with, never suggested or named in the app (D42). Size S.
4. **35f**: a list of every stored field in all 34 models and every typed setting, each marked locked or plain with the reason, and a check that keeps the list and the code in step (D44). Size S.
5. **35g**: lock the rest, which is dates, numbers and typed settings, in groups of models, each with a safety copy and the way back first (D44). Size M+, to be split.
6. **SY0**: sync groundwork. Drop the unique constraint from all 34 models, keep ids from doubling up, safety copy first. Size M+.
7. **SY1**: the iCloud sync switch. Off by default, the private database, per-device things stay per-device, sleep nights synced except any Apple Health already holds (D39), Clear everything says it clears every device. After SY0.
8. **SY2**: voice notes and Journal photos in sync. After SY1.
9. **SY3**: the recovery key shown as a QR code and scanned on the new device, with the typed key still the default (D40). With SY1.
10. **VN4a**: find who is speaking with a speaker-separation model on the recording, used in memory against the other voices in that one recording only, labelling Person 1, Person 2 and so on, then a people screen (how many were heard, a name for each beside a transcript preview, openable again later). The model ships inside the app; its size is measured first. Nothing is stored. Size L, to be split.
11. **VN4b**: replay and tap, for the more privacy-minded: play the recording back and tap where each new person starts, with no model. After VN4a.
12. **VN4c**: the words as a backup or beside the model: a language model reads only the transcript and suggests where the speaker changes, on the phone and through Ollama on your own computer, behind the AI switch. After VN4a.
13. **VN5**: speaker tags in exports, per entry and per person: include the name, hide it, or leave that person's words out. After VN4a.
14. **52**: refresh the Remotion promo with new screenshots and captions. The single source is already true (`remotion-project/src/Promo.tsx`, `npm run sync:promo`); what is left needs the app run on a simulator.
15. **53**: the long full-tour video, split into per-tab scenes, scripted from `website/src/content/guide.generated.json`. Waits on 52. Size L, to be split.
16. **54**: Android decision write-up, optional prototype spike. Android itself is far future (D4).

**Parked on purpose**

- **49, 50**: demo routes A and C, replaced by 55.
- **55**: the web demo made by one script from the app and its demo data (D3). Done last, just before the Android work.

## 4. Offered but not built

Nothing here is queued. Tell me which you want and it becomes a patch. The full list, by area, is Appendix D of `ANCHOR_PATCH_PLAN.md`. One item is tied to a patch above: turning locking off in place (an Unlock my data). The medication notes idea (B5) is held at your word and is not a to-do.
