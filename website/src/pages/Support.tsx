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
        Add your contacts under Plan, then Contacts. Long-press your lock screen, tap Customize, and add an Anchor widget. Tapping it opens Anchor to a confirmation screen with a call button. If the widget looks empty, open Plan once so it can refresh. Lock screen widgets can be seen without unlocking your phone, so only add one if you are comfortable with that.
      </Q>
      <Q q="Face ID is not working or I am locked out of the app">
        Anchor uses your device&rsquo;s own Face ID, Touch ID or passcode. Make sure Face ID is allowed for Anchor in Settings, then Face ID &amp; Passcode, then Other Apps. You can turn Require Face ID off in Settings, under Privacy, if you can get in. Settings is the gear at the top of Plan.
      </Q>
      <Q q="My notifications are not showing">
        Check Settings, then Notifications, then Anchor, and confirm notifications are allowed. Most of Anchor&rsquo;s reminders are off until you switch them on in Anchor&rsquo;s own Settings, the gear at the top of Plan, so look there too. Open Plan once after changing a trigger window or a reminder so they re-sync.
      </Q>
      <Q q="Can Anchor message my contacts automatically?">
        No. iOS does not allow apps to send messages silently. Anchor can remind you and open a message ready for you to review and send.
      </Q>
      <Q q="Where is my data, and can I move it to a new phone?">
        Your data lives only on your device. To move it, go to Settings, then Your data, and choose Make an encrypted backup. It includes photos and voice notes and is locked with a password you choose, so keep that password safe, because I cannot get it back for you. Send the file to the new device and use Import there. Export everything is plain text without photos or voice notes. Device backups may also restore your data if you restore your whole device.
      </Q>
      <Q q="How do I delete everything?">
        Settings, then Your data, then Clear all data. It cannot be undone. You can also delete the app, which removes its data from the device.
      </Q>
      <Q q="The crisis numbers are for the wrong country">
        On the Now tab, tap the region line at the bottom of the red crisis card and pick your region. Anchor uses your phone&rsquo;s region by default.
      </Q>
      <Q q="Does Anchor score or rate how I am doing?">
        No. A check-in shows the sliders where you left them and nothing is added up. There are no scores, no target hours for sleep and no streak pressure. The <Link to="/philosophy">philosophy</Link> page says more.
      </Q>
      <Q q="Do I need an account?">
        No. There is no account to make, and what you put in Anchor stays on your phone.
      </Q>
      <Q q="Can the sleep journal use Apple Health?">
        Yes, if you want it to. Apple Health is optional and sits at the bottom of the Sleep screen, with one switch for bringing nights in and one for saving the nights you type. Nothing is asked of Health until you switch one on, and you can remove what Anchor brought in or saved from the same screen.
      </Q>
      <Q q="Where is each part of the app explained?">
        The <Link to="/features">features</Link> page has an entry for each screen, and the question mark at the top of a screen in the app opens the same words.
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
