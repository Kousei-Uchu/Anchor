import { Link } from 'react-router-dom';
import { Page } from '../components/Page';
import { SUPPORT_EMAIL } from '../content/meta';

export default function Privacy() {
  return (
    <Page route="/privacy" title="Privacy Policy" meta="Effective 5 November 2026">
      <div className="panel">
        <p>
          <strong>The short version.</strong> Anchor keeps what you put into it on your own device. There are no accounts, no servers that receive your data, no analytics, no advertising, and no tracking. I (the developer) cannot see anything you write or save in the app.
        </p>
      </div>

      <h2>What Anchor stores</h2>
      <p>
        Everything you add is saved locally on your iPhone or iPad. That can include your safety plan, trusted contacts and their phone numbers, journal entries, check-ins, grounding tools, trigger windows, appointment details, messages and notes you write inside the app, and your settings. This data is stored in an on-device database that uses Apple&rsquo;s Data Protection, so it is encrypted by your device and tied to your passcode.
      </p>
      <p>None of it is sent to me or to any third party by the app.</p>

      <h2>Information shared with the home screen and lock screen widgets</h2>
      <p>
        To let the widgets work, Anchor shares a small summary with its own widget extension through an Apple app group on your device: the names and phone numbers of your top two contacts, whether a safety plan exists, the label of your next trigger window, and one de-escalation phrase and one affirmation that you wrote yourself. None of this leaves your device. Your journal entries, safety plan text and everything else are never shared with the widget.
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
        <li><strong>Notifications.</strong> Used for the reminders you set up: trigger windows, the daily check-in, and the optional reminder to reach out to a contact you chose. Anchor asks the first time you turn one of these on. They are scheduled on your device, and no push notification server is involved.</li>
        <li><strong>Calendar and Reminders.</strong> Used to suggest events for a journal day, to import today&rsquo;s reminders into &ldquo;Next hour only&rdquo;, and to add items you create there to Reminders. This information is read on your device and is only saved in Anchor if you tap to add it.</li>
        <li><strong>Photos.</strong> Used to suggest photos from the day you are journaling about, and to attach photos you pick. Only photos you choose are copied into Anchor.</li>
        <li><strong>Apple Music (MusicKit).</strong> Used to suggest recently played songs as journal context. This request is handled by Apple.</li>
        <li><strong>Journaling Suggestions.</strong> If you use Apple&rsquo;s suggestions picker, iOS shows you suggestions and passes back only the one you choose. Apple&rsquo;s own privacy terms apply to that feature.</li>
        <li><strong>Contacts.</strong> When you pick a trusted contact, iOS shows a contact picker. Anchor receives only the contact you select.</li>
      </ul>

      <h2>When data leaves your device</h2>
      <p>Only when you decide it should:</p>
      <ul>
        <li><strong>Messages.</strong> If you tap a button to message a contact, Anchor opens the standard iOS message composer. You review and send the message yourself. Anchor cannot send messages on its own.</li>
        <li><strong>Exports.</strong> Exports (JSON backup, CSV, PDF, and calendar files) are created on your device and handed to the iOS share sheet. Where they go is up to you.</li>
        <li><strong>Links.</strong> Grounding tools can open links such as Spotify, Discord or a web page. Those open in the relevant app or in your browser, and are then governed by that service&rsquo;s own privacy policy.</li>
        <li><strong>Backups.</strong> If you use iCloud Backup or a computer backup for your device, Apple may include Anchor&rsquo;s data in that backup according to your device settings. That is controlled by Apple and you.</li>
      </ul>

      <h2>Your control</h2>
      <p>
        In the app, go to Plan, then Your data, to see what is stored, export it, import a previous export, or clear everything. Deleting the app from your device removes its data from the device. Because I do not hold a copy, I cannot recover data for you if it is deleted, so keep your own exports if the content matters to you.
      </p>

      <h2>Children</h2>
      <p>
        Anchor is not directed at children under 13, and I do not knowingly collect any information from anyone, since the app does not collect data.
      </p>

      <h2>Not medical or emergency advice</h2>
      <p>
        Anchor is a personal organisation and support tool. It does not diagnose, treat or monitor any condition, and it does not contact emergency services or anyone else for you. The crisis numbers shown in the app are a convenience for the region you choose. If you or someone else is in immediate danger, call your local emergency number.
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
