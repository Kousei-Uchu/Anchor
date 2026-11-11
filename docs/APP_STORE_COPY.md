# App Store copy for Anchor

## Name
Anchor

## Subtitle (30 characters max)
Your private safety & support

## Promotional text (170 max)
Your safety plan, supports and journal in one private place, on your device only.

## Keywords (100 max, comma separated, no spaces after commas)
safety plan,journal,check-in,grounding,coping,wellbeing,reminders,widget,private,offline,crisis

## Description
Anchor keeps the things you need on hard days in one calm, private place.

Build a safety plan in your own words. Keep your trusted contacts one tap away. Set gentle reminders for the times of day that are tough. Check in with yourself, jot things down, and bring notes to your appointments.

NOW
Your quick access tab. Crisis numbers for your region, your check-in, your people, and grounding tools you wrote yourself, one step at a time.

PLAN
Your safety plan, trusted contacts, trigger windows, appointments, tasks, routines and lists, decision presets, de-escalation scripts, affirmations and an optional sleep journal that can use Apple Health if you want it. All of it is editable, and nothing is written for you.

JOURNAL
A private timeline with a Markdown editor, photos and drawings. Optional suggestions from your calendar, photos, music and Apple's journaling suggestions.

BRIDGE
Prepare for and reflect on appointments with one or more providers, keep a running list of things to raise, write goals of your own, map a pattern as a feedback loop, and make an export for someone as a PDF or a web page, with a password if you like.

THREAD
A message log with voice notes, message starters of your own, a page for each person, notes to your future self, things you have not said yet, a boundaries list, and a support calendar you can share as a file.

RECOVERY
Optional day counters for something you are stepping away from, with reasons you write yourself, a daily pledge and a timer for riding out an urge. No accounts, no community, and nothing is scored or compared.

PRIVATE BY DESIGN
No account. No ads. No tracking. Your data stays on your device, protected with an optional Face ID lock, and you can make an encrypted backup with a password you choose. Lock screen and home screen widgets give you a call shortcut without opening the app.

Anchor is a personal organisation tool. It is not a medical device, does not give medical advice, and cannot contact anyone or emergency services for you. If you are in immediate danger, call your local emergency number.

## What's New (version 1.0)
First release.

## TestFlight "What to test"
Thanks for testing Anchor. Please try: setting up contacts and a safety plan, adding the lock screen widget and tapping it, creating a trigger window and checking the notification arrives, writing a journal entry, trying the journal suggestions, adding a task, logging a night of sleep, making an export for someone and an encrypted backup, changing the crisis region on the Now tab, and using it on iPad if you have one. Tell me anything confusing, broken, or unsettling.

## App Review notes
Anchor is a fully on-device personal planning and journaling app. There are no accounts, no login, and the app does not talk to any developer server, so no demo account is needed.

On first launch a short tour is shown. The app has its own optional Face ID lock (Plan, Settings) which is on by default and uses the standard system prompt. Permissions (Calendar, Reminders, Photos, Apple Music, Apple Health for sleep, Microphone for voice notes and Dictate, Speech Recognition for Dictate, Camera only to scan a recovery key shown as a QR code on another device, Contacts, notifications, Journaling Suggestions) are requested only when the related feature is used, and all are optional. In Journaling Suggestions, calendar, photos and music each ask only when their own button is tapped. Every reminder is off until the user switches it on, and notifications are requested the first time one is switched on. Apple Health is read only after the user taps Connect on the Sleep screen, and typed nights are written to Health only if a separate switch is turned on. Nothing is shared or used for advertising.

The camera is used only when the user taps Scan a QR code, in the box where a recovery key is typed, to read a recovery key from the screen of their other device (Settings, Encryption, or Settings, iCloud sync). The scanner looks for that one code, saves no photo or video and sends nothing anywhere; typing the key always works instead.

Crisis numbers on the Now tab are shown for the user's region (changeable from the card). The app makes no diagnosis or treatment claims and states that it is not a medical device or emergency service.

Widgets share only contact names and numbers, whether a safety plan exists, the next trigger window label, and one de-escalation phrase and one affirmation the user wrote, through an App Group, stored locked with a key that is kept out of backups. A Recovery counter widget shows a generic label unless the user turns on showing that counter's name. The focus timer can show on the lock screen and in the Dynamic Island if the user switches that on, and it never shows the task. Widgets are optional. Lock screen widgets are visible without unlocking the phone, which the privacy policy explains.

AI tools (Settings, AI tools) are off unless the user switches them on. The tools are Make shorter in the Journal, Break into steps and Estimate time on a task, and Tidy a braindump (Turn into tasks, Turn into things to raise), each of which shows the exact text and asks before every use and runs on Apple's on-device model, on the phone, or, only if the user sets it up, on the user's own computer with Ollama, at an address the user types: on their own network, or away from home through Tailscale or over https, which Anchor uses only after the user confirms that exact address. Nothing is sent to the developer or to any server of ours, and the shorter version is not saved unless the user taps Keep. Also only if the user sets it up, an Other provider: an https address, a key and a model name for a service the user chooses, empty to begin with, never suggested or named by the app. The text goes there with the user's key only after the user taps Send, every time, and the key is kept in the phone's Keychain, not in a backup. The App Privacy answers stay as they are: no data is collected, because the text goes only to the computer or service at the address the user typed (and, away from home, confirmed), and never reaches the developer or any server of ours. For the Other provider that is my reading and not Apple's: check it against Apple's wording on third-party partners before submission (D68). The local network permission is requested only on first use.

Dictate in the Journal (Settings, Journal) is off unless the user switches it on. It turns speech into text with on-device recognition only: the app requires the phone to do it without a server, and does not start if the phone cannot do it for the user's language. No sound is stored unless the user also switches on Keep a voice note while dictating, which saves it on the phone as a voice note on the journal page, like a voice note on a message. Label who is speaking (also off to begin with) lets the user tap Speaker 1 or Speaker 2 while dictating, which only starts a new line with that label in the entry; the app does not tell voices apart and keeps nothing about a voice. Nothing is sent anywhere, so the App Privacy answers stay as they are: no data is collected. The speech recognition and microphone questions are asked on first use.

iCloud sync (Settings, iCloud sync) is off unless the user switches it on, and it starts only once every field that holds their words is locked on the phone. It uses the user's own private iCloud database (CloudKit) and key-value store, only between their own devices, and the developer has no access to it. What is sent is locked first; the data key never leaves the phone (a second device asks for the recovery key, typed or scanned from a QR code on the first), and the small recovery file put in iCloud is sealed under that key. Voice notes and Journal photos are a separate switch and only locked files are sent. Nights read from Apple Health are not sent. App Privacy answers: no data is collected by the developer; the sync data is encrypted before it leaves the device and is not linked to an identity the developer holds.

Showcase mode (Settings, Your data and help) runs the app on made-up content held only in memory, for showing it to someone, and the user's own data is not opened while it is on.

## Support URL
https://anchor.aspens.page/support

## Privacy Policy URL
https://anchor.aspens.page/privacy

## Copyright
2026 YOUR NAME
