# Anchor: what is left

*Only what is still to do. When something is finished, confirmed or answered, it is deleted from this file in the same patch, never moved to a done list. Finished work is in the Progress table of `ANCHOR_PATCH_PLAN.md` and in `docs/PLAN_CHANGELOG.md`. Last updated: 11 Nov 2026, after DOC29.*

## 1. Waiting on you

**Words and files**

- The words for the About screen's creator section (D23, 1).
- The licence files you said you would attach, so the `LICENSE` file can be written (D23, 2). Nothing is written yet.

**Needed before SY1b can be written (iCloud sync switch)**

- The iCloud capability and the container `iCloud.page.aspens.anchor` are in `Anchor.entitlements` (your commit `b9e7ca6`). Still to check: that the container is registered in your Apple developer account and ticked on the app target, which only you can see.
- A second device signed in to the same Apple ID to try it on. A simulator cannot show whether two devices agree.
- A go-ahead on the two relationships (`AppointmentSeries.occurrences`, `DecisionPresetCategory.choices`): CloudKit wants them optional with an inverse, which changes how a stored link is kept. I will make the change in its own small patch, and it needs the safety copy and your data on a copy first.
- How the second device gets the data key: D40 says the recovery key is typed on the new device. I have not checked that a screen for typing it in on a new device exists; that is the first thing I will look at once the above is in place.

**Things to read and answer**

- D70: the review run cannot try AI, dictation or locking, and this phone has no Apple Intelligence. Say which of (a) a made-up-answers stand-in for AI in the review run only, (b) a test store on disk, (c) dropping those stops from the review bar, you want. I recommend (a) and (c).
- D69 and `docs/FIELD_INVENTORY.md` (35f): the list of every field and setting, locked or plain, with the reason. Nothing to try on your phone. Say which verdicts to change; the ones I left plain on a judgment are reminder times, the crisis-numbers country, the focus timer lengths and times the app sets for itself.

**Things only you can try**

- D29a: try the Apple Health sleep cleanup on a real device (a review run never touches Health). The Apple Health checklist is in `docs/SLEEP.md`.
- D28: read the privacy page and open its links, before a TestFlight build.

## 2. Pushed and building, waiting for a try on your phone

Everything here builds and launches on your phone (confirmed 11 Nov 2026, after FIX1 and FIX2); what is left is trying each one. Quickest way to check many at once: `scripts/review-on-device.sh` (the numbered review bar, Patch R1). On your phone: `DEVICE="Demon Child" scripts/review-on-device.sh`. The review bar (R4) still lists stops for the second group below, and those cannot be run from it.

**Can be tried in the review run** (`scripts/review-on-device.sh`, made-up content)

- RV1a: Task cards, the quiet line is now a few small facts that wrap instead of being cut off.
- 30p2: Settings, After-session reminders, a switch for each person, that evening or the next morning.
- 35e: Settings now shows Encryption, Safety copy and Lock my data in every build. Open each from Settings and check the names; the Encryption guide page (the question mark) now opens. A new check on the website: Features should show an Encryption entry.

**Cannot be tried in the review run.** The review run turns AI tools, dictation, Lock my data and Safety copy off, because it uses a throwaway in-memory store (`DemoMode`), so the review bar has nothing to show for these. They need the normal app, on your own data or a copy of it. AI1 to AI9 also need somewhere to run: this phone, an iPhone 14 Pro, has no Apple Intelligence, so On this phone will say it cannot run it. Ollama on your Mac (AI5, AI8) or an Other service (AI6) are the ways to try them here.

- 35d: Settings, Lock my data, Voice notes and photos (test builds only). Try on a copy of your data, with the safety copy first.
- AI1: Settings, AI tools: the consent sheet, where it runs, Don't ask again (test builds only until the first real tool).
- AI2: Make shorter in the Journal editor's three dots menu: Keep or Discard, folded original.
- AI3: Break into steps and Estimate time under a task's steps.
- AI4: Tidy a braindump from the Journal page's three dots, Add several on Tasks and the task helper.
- AI5: Settings, AI tools, On my computer: an address on your own network, a model name, Look for models.
- VN1: Settings, Journal, Dictate in the Journal, then the microphone on a Journal page.
- VN2: Settings, Journal, Keep a voice note while dictating.
- VN3: Label who is speaking while dictating, and Rename speakers.
- AI7: with AI tools off (Settings, AI tools), a Journal page's three dots should show Tidy a braindump greyed and no Make shorter; Things to raise, Add several (after typing words) and a named task's steps should show the greyed buttons; tapping one should say AI tools are off and where to turn them on. Turn AI tools on and the real buttons should be back. A menu item may not look grey.
- AI8: Settings, AI tools, On my computer: type a Tailscale number (100.x), and it should say the address is away and show Use this address; nothing should connect, and Look for models should stay greyed, until you confirm. Confirm it, then Look for models, then use a tool: the sheet should say the computer is away and that it can use mobile data. Change one digit of the address and it should ask again. A plain http address with a name, such as http://my-mac.example.com, should be refused and ask for https. A home address should behave as before.
- AI9: make a shorter version in a Journal page and keep it, then Export for someone (Bridge) or CSV or PDF (Settings, Your data) with Include AI Optimised versions ticked. The words you wrote should sit under Original: the writer's own words, and the shorter version under its AI Optimised label, with your words not appearing twice. Untick it and the export should be as before. Say if you meant two separate rows in the CSV (D67).
- AI6: Settings, AI tools, Where it runs, Other (a third choice, empty to begin with). Type an address starting with https://, a key and a model name for a service you already use; a plain http address, a name with no dot and an address with a ? in it should each be refused with a line. The key shows as dots and Remove key clears it. Use a tool with Other chosen: the sheet should show the address and model, say Anchor cannot see how it keeps the text, and have no Don't ask again. A wrong key should say the provider did not accept it. Also say how the store should read the privacy answers for it (D68).
- 35g1a, 35g1b, 35g2, 35g3, 35g4, SY0 and SY1a: Settings, Lock my data. If your text is already locked it should show More to lock with Lock the rest; take the safety copy first, close and open the app, and read the result under Last time. Then open check-ins in the Journal, Sleep in Plan and Bridge, a Recovery counter with its savings, milestones, urges and the day review: everything should look as it did. Record a slip and check Times still adds up. Make a new check-in, night and urge and check they show. For 35g2 also open the Journal timeline, bookmark an entry, look at Thread (messages, support days, future notes, unsent drafts), Bridge's lists and a contact's available hours, and check the tab widgets. Use Go back in Safety copy once to check the way back. They need a build first: the generated accessors have never been compiled.
- SY1a: open the new build, nothing should look different, and adding a new item of any kind should work as before. Do this together with SY0 and make the safety copy first.
- SY0: make a safety copy first (Settings, Safety copy), then open the new build. Everything should be there as before. Import the same backup file twice: the second time should say nothing new to import.
- 35g4: also open Settings and Lock my data (More to lock), the three sleep words, an AI address and model, Today's plan, answering an escalation reminder, and Sleep's Apple Health saving. Everything should look as before, and nothing should save twice to Health.
- 35g3: after the steps above, also open Tasks (a task with a due day, one with none, one set aside, one with an energy tag, focus totals and an estimate, ticking one done and back), Plan's safety plan and boundaries, Trigger windows (days and times, in Settings too) and Appointments (a usual day and time, moving one session), the quick lists and routines on Now and in Plan (their order newest first), and the diagrams on the Plan widget. Everything should look as it did. Make a new task and a new hard time and check they show.

**Website**

- 47: the website's Features and Philosophy pages.
- 48: the website's About page, the Support answers and the Privacy page.
- 51: the website's `/beta` page. Sign-ups stay closed until you change the flag in `website/src/content/beta.ts`, and the TestFlight link there is empty.

## 3. Not started, in order

1. **SY1b**: the iCloud sync switch. It must also remove `cloudKitDatabase: .none` from every store (FIX2), or sync stays off. Off by default, the private database, per-device things stay per-device, sleep nights synced except any Apple Health already holds (D39), Clear everything says it clears every device. The two relationships (`AppointmentSeries.occurrences`, `DecisionPresetCategory.choices`) first need to be optional with an inverse, which `scripts/check-cloudkit-ready.mjs` lists; then the CloudKit container and entitlement, which need your Apple developer account and a device. After SY1a is checked on your phone.
2. **SY2**: voice notes and Journal photos in sync. After SY1.
3. **SY3**: the recovery key shown as a QR code and scanned on the new device, with the typed key still the default (D40). With SY1.
4. **VN4a**: find who is speaking with a speaker-separation model on the recording, used in memory against the other voices in that one recording only, labelling Person 1, Person 2 and so on, then a people screen (how many were heard, a name for each beside a transcript preview, openable again later). The model ships inside the app; its size is measured first. Nothing is stored. Size L, to be split.
5. **VN4b**: replay and tap, for the more privacy-minded: play the recording back and tap where each new person starts, with no model. After VN4a.
6. **VN4c**: the words as a backup or beside the model: a language model reads only the transcript and suggests where the speaker changes, on the phone and through Ollama on your own computer, behind the AI switch. After VN4a.
7. **VN5**: speaker tags in exports, per entry and per person: include the name, hide it, or leave that person's words out. After VN4a.
8. **52**: refresh the Remotion promo with new screenshots and captions. The single source is already true (`remotion-project/src/Promo.tsx`, `npm run sync:promo`); what is left needs the app run on a simulator.
9. **53**: the long full-tour video, split into per-tab scenes, scripted from `website/src/content/guide.generated.json`. Waits on 52. Size L, to be split.
10. **54**: Android decision write-up, optional prototype spike. Android itself is far future (D4).

**Parked on purpose**

- **49, 50**: demo routes A and C, replaced by 55.
- **55**: the web demo made by one script from the app and its demo data (D3). Done last, just before the Android work.

## 4. Offered but not built

Nothing here is queued. Tell me which you want and it becomes a patch. The full list, by area, is Appendix D of `ANCHOR_PATCH_PLAN.md`. One item is tied to a patch above: turning locking off in place (an Unlock my data). The medication notes idea (B5) is held at your word and is not a to-do.
