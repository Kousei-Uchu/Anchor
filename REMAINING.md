# Anchor: what is left

*Only what is still to do. When something is finished, confirmed or answered, it is deleted from this file in the same patch, never moved to a done list. Finished work is in the Progress table of `ANCHOR_PATCH_PLAN.md` and in `docs/PLAN_CHANGELOG.md`. Last updated: 10 Nov 2026, after DOC27.*

## 1. Waiting on you

**Words and files**

- The words for the About screen's creator section (D23, 1).
- The licence files you said you would attach, so the `LICENSE` file can be written (D23, 2). Nothing is written yet.

**Open questions** (none of them blocks the patch in front of it; the number is the row in 0.4 of the plan)

- D63: how the speaker-separation model's files reach the phone for VN4, shipped inside the app or fetched once after you tap. Also say if my readings of your 10 Nov answers are off.
- D43: AI Optimised blocks in exports. You asked how it is built and what else it could be; explained in chat. Say if it stays as built.
- D44: which fields are locked. You asked what the question is; explained in chat. Say if the list is right.

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
- 47: the website's Features and Philosophy pages.
- 48: the website's About page, the Support answers and the Privacy page.
- 51: the website's `/beta` page. Sign-ups stay closed until you change the flag in `website/src/content/beta.ts`, and the TestFlight link there is empty.

The website patches (47, 48, 51) were typechecked and built in a scratch copy only; no Swift changed in them.

## 3. Not started, in order

1. **35e**: show Encryption, Safety copy and Lock my data to everyone in Settings, with no option and without "(test build)" in their names (D45). Size S.
2. **AI7**: with AI tools off, Make shorter stays hidden, and Tidy a braindump, Break into steps and Estimate time stay on screen greyed out, saying where the switch is (D41). Size S.
3. **AI8**: Ollama addresses off the home network, such as Tailscale or IPv6, accepted after a prompt and a confirmation (D56). Size S.
4. **AI6**: other AI provider as a plain setting: address, key and model in the OpenAI API format, off and empty to begin with, never suggested or named in the app (D42). Size S.
5. **SY0**: sync groundwork. Drop the unique constraint from all 34 models, keep ids from doubling up, safety copy first. Size M+.
6. **SY1**: the iCloud sync switch. Off by default, the private database, per-device things stay per-device, sleep nights synced except any Apple Health already holds (D39), Clear everything says it clears every device. After SY0.
7. **SY2**: voice notes and Journal photos in sync. After SY1.
8. **SY3**: the recovery key shown as a QR code and scanned on the new device, with the typed key still the default (D40). With SY1.
9. **VN4**: find who is speaking with a speaker-separation model on the recording, labelling Person 1, Person 2 and so on, then a people screen (how many were heard, a name for each beside a transcript preview, openable again later). The manual taps from VN3 stay. Waits on D63. Size L, to be split.
10. **52**: refresh the Remotion promo with new screenshots and captions. The single source is already true (`remotion-project/src/Promo.tsx`, `npm run sync:promo`); what is left needs the app run on a simulator.
11. **53**: the long full-tour video, split into per-tab scenes, scripted from `website/src/content/guide.generated.json`. Waits on 52. Size L, to be split.
12. **54**: Android decision write-up, optional prototype spike. Android itself is far future (D4).

**Parked on purpose**

- **49, 50**: demo routes A and C, replaced by 55.
- **55**: the web demo made by one script from the app and its demo data (D3). Done last, just before the Android work.

## 4. Offered but not built

Nothing here is queued. Tell me which you want and it becomes a patch. The full list, by area, is Appendix D of `ANCHOR_PATCH_PLAN.md`. One item is tied to a patch above: turning locking off in place (an Unlock my data). The medication notes idea (B5) is held at your word and is not a to-do.
