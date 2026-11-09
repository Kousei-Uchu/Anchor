import { Page } from '../components/Page';
import { BETA_SIGNUP_OPEN, BETA_TESTFLIGHT_URL } from '../content/beta';
import { SUPPORT_EMAIL } from '../content/meta';

/** Unlisted: not in the header, the footer or any sitemap, and marked noindex (see content/meta.ts and vercel.json). */
export default function Beta() {
  const invite = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Anchor beta')}`;
  return (
    <Page route="/beta" title="Join the beta" meta="Early testing on iPhone and iPad">
      <p>
        Anchor is a private safety plan, contacts and journal app for iPhone and iPad. It is not on the App Store yet, and I am looking for a few people to try it first and tell me what is confusing, missing or broken.
      </p>

      <h2>What you would be doing</h2>
      <p>
        Using it the way you would use it anyway, on whichever parts suit you. Nothing is required, and you can stop whenever you like. If something goes wrong or reads badly, an email or the feedback button in TestFlight is all it takes.
      </p>

      <h2>Before you join</h2>
      <ul>
        <li>It is an early build. Parts of it will change, and some will have rough edges.</li>
        <li>Your data stays on your phone, so I cannot see it or get it back for you. Make a backup from Settings, then Your data, now and then.</li>
        <li>Please do not rely on it as your only safety plan, and please do not email me private content from it.</li>
        <li>Anchor is not a medical device and not an emergency service. If you are in danger, call your local emergency number or a crisis line.</li>
        <li>You need TestFlight, Apple&rsquo;s free app for trying apps before release.</li>
      </ul>

      <h2>Sign up</h2>
      {!BETA_SIGNUP_OPEN ? (
        <p>Sign-ups are closed for now.</p>
      ) : BETA_TESTFLIGHT_URL ? (
        <p>
          <a className="button" href={BETA_TESTFLIGHT_URL} rel="noopener noreferrer">Join on TestFlight</a>
        </p>
      ) : (
        <p>
          <a className="button" href={invite}>Ask for an invite</a>
        </p>
      )}
    </Page>
  );
}
