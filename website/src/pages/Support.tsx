import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { Page } from '../components/Page';
import { SUPPORT_EMAIL } from '../content/meta';

const Q = ({ q, children }: { q: string; children: ReactNode }) => (
  <details>
    <summary>{q}</summary>
    <p>{children}</p>
  </details>
);

export default function Support() {
  return (
    <Page route="/support" title="Support" meta="Help for the Anchor app">
      <div className="panel">
        <p>
          Need a hand with Anchor? Email <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> and include your iOS version and what you were doing when the problem happened. Please do not email private content from your journal or plan.
        </p>
      </div>
      <div className="panel callout">
        <p>
          <strong>If you are in danger right now,</strong> call your local emergency number (for example 000 in Australia, 911 in the US, 999 in the UK) or a crisis line in your country. I cannot respond to emails in real time.
        </p>
      </div>

      <h2>Common questions</h2>

      <Q q="How do I make the lock screen widget call someone?">
        Add your contacts under Plan, then Contacts. Long-press your lock screen, tap Customize, and add an Anchor widget. Tapping it opens Anchor to a confirmation screen with a call button. If the widget looks empty, open Plan once so it can refresh.
      </Q>
      <Q q="Face ID is not working or I am locked out of the app">
        Anchor uses your device&rsquo;s own Face ID, Touch ID or passcode. Make sure Face ID is allowed for Anchor in Settings, then Face ID &amp; Passcode, then Other Apps. You can turn the Anchor lock off in Plan, then Preferences, if you can get in.
      </Q>
      <Q q="My notifications are not showing">
        Check Settings, then Notifications, then Anchor, and confirm notifications are allowed. Reminders are scheduled from your trigger windows, appointments and daily check-in. Open Plan once after changing them so they re-sync.
      </Q>
      <Q q="Can Anchor message my contacts automatically?">
        No. iOS does not allow apps to send messages silently. Anchor can remind you and open a message ready for you to review and send.
      </Q>
      <Q q="Where is my data, and can I move it to a new phone?">
        Your data lives only on your device. To move it, go to Plan, then Your data, export a full backup, send it to the new device, and use &ldquo;Import from a previous export&rdquo;. Device backups may also restore it if you restore your whole device.
      </Q>
      <Q q="How do I delete everything?">
        Plan, then Your data, then clear everything. You can also delete the app, which removes its data from the device.
      </Q>
      <Q q="The crisis numbers are for the wrong country">
        On the Now tab, tap the region line at the bottom of the red crisis card and pick your region. Anchor uses your phone&rsquo;s region by default.
      </Q>
      <Q q="Does Anchor work on iPad and Mac?">
        Yes on iPhone and iPad. On Macs with Apple silicon it can run as an iPad app. Lock screen widgets and some phone-only features are not available there.
      </Q>
      <Q q="Something is broken or looks wrong">
        Please email me with what you were doing, your device model and iOS version. If the app shows a red banner saying it could not open your saved data, close and reopen the app first, and email me before adding anything new.
      </Q>

      <h2>Privacy</h2>
      <p>
        Anchor keeps your data on your device and does not collect it. Read the <Link to="/privacy">privacy policy</Link>.
      </p>
    </Page>
  );
}
