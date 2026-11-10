import { Link } from 'react-router-dom';
import { Page } from '../components/Page';
import { SUPPORT_EMAIL } from '../content/meta';

export default function Privacy() {
  return (
    <Page route="/privacy" title="Privacy Policy" meta="Effective 10 November 2026">
      <div className="panel">
        <p>
          <strong>The short version.</strong> Anchor keeps what you put into it on your own device. There are no accounts, no servers that receive your data, no analytics, no advertising, and no tracking. I (the developer) cannot see anything you write or save in the app.
        </p>
      </div>

      <h2>What Anchor stores</h2>
      <p>
        Everything you add is saved locally on your iPhone or iPad. That can include your safety plan, trusted contacts and their phone numbers, journal entries, check-ins, sleep notes, tasks, routines and lists, Recovery counters with their start dates, urges and reasons, grounding tools, trigger windows, appointment details, messages and notes you write inside the app, and your settings. This data is stored in an on-device database that uses Apple&rsquo;s Data Protection, so it is encrypted by your device and tied to your passcode.
      </p>
      <p>None of it is sent to me or to any third party by the app.</p>

      <h2>Information shared with the home screen and lock screen widgets</h2>
      <p>
        To let the widgets work, Anchor shares a small summary with its own widget extension through an Apple app group on your device: the names and phone numbers of your top two contacts, whether a safety plan exists, the label of your next trigger window, and one de-escalation phrase and one affirmation that you wrote yourself. None of this leaves your device. The summary is stored locked, with a key that stays on your phone and is left out of phone backups. Your journal entries, safety plan text and everything else are never shared with the widget.
      </p>
      <p>
        If you add the Recovery counter widget, it is given the same kind of summary for up to two counters: a label, when the current run started, the days from earlier runs and how that counter counts. The label is a generic one, such as &ldquo;Your counter&rdquo;, unless you turn on showing that counter&rsquo;s name outside the app. It is stored locked in the same way.
      </p>
      <p>
        Widgets on your lock screen can be seen without unlocking your phone, and Anchor&rsquo;s own Face ID lock does not cover them. Only add a widget if you are comfortable with that information being visible.
      </p>

      <h2>Optional permissions</h2>
      <p>
        Anchor asks for these only when you use the feature that needs them, and every one is optional. You can change them at any time in Settings, then Anchor.
      </p>
      <ul>
        <li><strong>Face ID or passcode.</strong> Anchor can lock itself using Face ID, Touch ID or your passcode. This is handled entirely by iOS. Anchor never receives your biometric data.</li>
        <li><strong>Notifications.</strong> Used for the reminders you set up: trigger windows, the daily check-in, the optional reminders to reach out to a contact you chose, including a regular hello, a reminder about a day on your Support calendar, a follow-up a few days after you write to someone and a nudge at the start of a trigger window that a person you chose is one option, a reminder after a session to ask whether you want to tell a person you chose how it went, reminders for sessions, routine reminders, the sleep morning reminder, the Recovery pledge, evening review and milestones, and the focus timer&rsquo;s alert. All of them are optional: none is on until you set it up or switch it on, and Anchor asks the first time you do. They are scheduled on your device, and no push notification server is involved. The words on the lock screen are short and generic. A trigger window reminder says only Anchor and a plain line on the lock screen. The label you gave the window and a line you wrote in your own safety plan travel inside the reminder, on your device, and show only once you open it. The one exception is one you control: a Recovery milestone shows a counter&rsquo;s name only if you turned that on for that counter.</li>
        <li><strong>Live Activities.</strong> The focus timer can show on your lock screen and in the Dynamic Island while it runs, if you switch that on. It shows only the phase and the time left, never the task. It is created on your device and nothing is sent to any server.</li>
        <li><strong>Calendar and Reminders.</strong> Used to suggest events for a journal day, to import reminders you choose into your task list, and to tick them off in Reminders when you finish them in Anchor. This information is read on your device and is only saved in Anchor if you tap to add it.</li>
        <li><strong>Microphone.</strong> Used when you choose to record a voice note on a message, and when you tap Dictate in the Journal, which you have to switch on in Settings first. Anchor asks the first time you do. A voice note is saved on your device and goes nowhere unless you send or share it yourself. Dictate does not keep the sound unless you also switch on Keep a voice note while dictating, in Settings. Then it is saved on your device as a voice note on that journal page, you choose afterwards whether to keep the words, the voice note or both, and it goes nowhere unless you share it yourself.</li>
        <li><strong>Speech recognition.</strong> Used only if you switch on Dictate in Settings and then tap it. Anchor asks the first time. It turns what you say into text on your phone, and Anchor tells the phone to do that without any server, so your voice is not sent to Apple or to anyone else. If your phone cannot do that for your language, Dictate says so and does not start. The words go into your journal entry, which is stored like the rest of it. If you also switch on Label who is speaking, tapping Speaker 1 or Speaker 2 while Dictate listens only starts a new line with that label in your entry. Anchor does not tell voices apart and keeps nothing about a voice, only the words in your entry.</li>
        <li><strong>Apple Health (sleep).</strong> Used only if you choose to connect it from the Sleep screen. If you connect it, Anchor reads your sleep so the nights Apple Health already has can appear in your sleep journal, and keeps its own copy of one summary per night on your device. If you separately turn on saving, Anchor writes the nights you type to Apple Health, marked as coming from Anchor, and can remove them again. None of it is sent anywhere, used for advertising or stored in iCloud by Anchor. Remove imported sleep deletes the copy in Anchor, and Remove what Anchor saved deletes what Anchor wrote to Health.</li>
        <li><strong>Photos.</strong> Used to suggest photos from the day you are journaling about, and to attach photos you pick. Only photos you choose are copied into Anchor.</li>
        <li><strong>Apple Music (MusicKit).</strong> Used to suggest recently played songs as journal context. This request is handled by Apple, under <a href="https://www.apple.com/legal/privacy/" target="_blank" rel="noopener noreferrer">Apple&rsquo;s Privacy Policy</a>.</li>
        <li><strong>Journaling Suggestions.</strong> If you use Apple&rsquo;s suggestions picker, iOS shows you suggestions and passes back only the one you choose. Apple&rsquo;s own privacy terms apply to that feature: see <a href="https://www.apple.com/legal/privacy/" target="_blank" rel="noopener noreferrer">Apple&rsquo;s Privacy Policy</a>.</li>
        <li><strong>Contacts.</strong> When you pick a trusted contact, iOS shows a contact picker. Anchor receives only the contact you select.</li>
      </ul>

      <h2>AI tools (optional)</h2>
      <p>
        AI tools are off unless you switch them on in Settings, and one switch turns all of them off. So far these are Make shorter in the Journal, Break into steps and Estimate time on a task, and Tidy a braindump, which turns words you pick into tasks or things to raise. Each time you use one, Anchor shows you the exact text it will send, where it goes and what happens to it, and nothing is sent until you tap Send. It runs on Apple&rsquo;s on-device model on your phone, so the text does not leave it, or, only if you set it up, on your own computer with Ollama, in which case the text goes to that computer and nowhere else. At home, Anchor accepts only an address on your own network and never uses the mobile network for it, and the phone asks your permission the first time Anchor connects to a device on your local network. Away from home, Anchor accepts a Tailscale number or an https address, but only after you confirm that exact address, and then it can use mobile data. What Ollama keeps on your computer is set there, and Anchor cannot see it. You can also, if you want to, give an address, a key and a model name for a service of your own choosing. It is empty until you fill it in, and Anchor does not suggest or name one. The text you pick then goes to that address over https, with your key, only after you tap Send each time, and Anchor cannot see how that service keeps it. Your key stays in your phone&rsquo;s Keychain and is not in a backup or an export. Anchor keeps no log of what was sent. A shorter version is not added to your entry until you tap Keep, your original stays with it, and it is left out of exports unless you switch it on for that export, in which case it comes beside your original words, each labelled. Suggested steps, times, tasks and things to raise are added only when you tap.
      </p>

      <h2>When data leaves your device</h2>
      <p>Only when you decide it should:</p>
      <ul>
        <li><strong>Messages.</strong> If you tap a button to message a contact, Anchor opens the standard iOS message composer. You review and send the message yourself. Anchor cannot send messages on its own.</li>
        <li><strong>Exports.</strong> Exports (JSON backup, encrypted backup, CSV, PDF, and calendar files) are created on your device and handed to the iOS share sheet. An encrypted backup is locked with a password you choose, which is never stored or sent, so I cannot open it or recover it for you. Where exports go is up to you.</li>
        <li><strong>Links.</strong> Grounding tools can open links such as Spotify, Discord or a web page. Those open in the relevant app or in your browser, and are then governed by that service&rsquo;s own privacy policy, such as <a href="https://www.spotify.com/legal/privacy-policy/" target="_blank" rel="noopener noreferrer">Spotify&rsquo;s</a> or <a href="https://discord.com/privacy" target="_blank" rel="noopener noreferrer">Discord&rsquo;s</a>.</li>
        <li><strong>Backups.</strong> If you use iCloud Backup or a computer backup for your device, Apple may include Anchor&rsquo;s data in that backup according to your device settings. That is controlled by Apple and you, and Apple&rsquo;s terms for it are in <a href="https://www.apple.com/legal/privacy/" target="_blank" rel="noopener noreferrer">its Privacy Policy</a>.</li>
      </ul>

      <h2>Your control</h2>
      <p>
        In the app, go to Plan, then Your data, to see what is stored, export it, import a previous export, or clear everything. Deleting the app from your device removes its data from the device. Because I do not hold a copy, I cannot recover data for you if it is deleted, so keep your own exports if the content matters to you.
      </p>

      <h2>Showcase mode</h2>
      <p>
        Showcase mode is an optional setting for showing the app to someone without showing them your own content. While it is on, Anchor runs on made-up content that exists only in memory and is gone when the app closes, and your real data is not opened. The widgets show made-up content in place of yours and waiting reminders are removed from the phone, and your own widgets and reminders are put back when you turn it off. Sharing and exporting work on the made-up content only, and the encrypted backup, importing and clearing are switched off.
      </p>
      <p>
        If you set a showcase passcode, Anchor keeps a salted hash of it in your device&rsquo;s Keychain, never the passcode itself, and it stays on this device. Your phone&rsquo;s own Face ID or passcode can always turn showcase mode off, so forgetting the showcase passcode does not lock you out. None of this is sent anywhere.
      </p>

      <h2>Children</h2>
      <p>
        Anchor is not directed at children under 13, and I do not knowingly collect any information from anyone, since the app does not collect data.
      </p>

      <h2>Not medical or emergency advice</h2>
      <p>
        Anchor is a personal organisation and support tool. It does not diagnose, treat or monitor any condition, and it does not contact emergency services or anyone else for you. The crisis numbers shown in the app are a convenience for the region you choose. If you or someone else is in immediate danger, call your local emergency number.
      </p>

      <h2>Reading this policy</h2>
      <p>
        If you would like help reading a privacy policy, this one or any other, Reject Convenience has a free <a href="https://rejectconvenience.com/privacy-visualizer/" target="_blank" rel="noopener noreferrer">Privacy Visualizer</a>. It lists the kinds of data an app can collect, based on Apple&rsquo;s <a href="https://developer.apple.com/app-store/app-privacy-details/" target="_blank" rel="noopener noreferrer">App Store privacy categories</a>. You mark each one as you read, and each has a short explanation and search terms for skimming a policy. I am not connected to it, and nothing from Anchor is sent to it. It is a separate website with its own privacy practices.
      </p>

      <h2>Changes to this policy</h2>
      <p>
        Anchor is an early build and features may change, but this commitment will not: it sends no data, or at most the minimum a feature truly needs. If that ever changes, you will be told immediately in the app, and I will update this page before the change ships.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about this policy: <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>. You can also visit the <Link to="/support">support page</Link>.
      </p>
    </Page>
  );
}
