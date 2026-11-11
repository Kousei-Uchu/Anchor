import { Link } from 'react-router-dom';
import { Page } from '../components/Page';
import {
  ABOUT_CONTACT_NOTE,
  ABOUT_CREATOR_CONTACT,
  ABOUT_CREATOR_INTRO,
  ABOUT_CREATOR_LINE,
  ABOUT_CREATOR_NAME,
  ABOUT_CREATOR_SITE_URL,
  ABOUT_CREATOR_STORY,
  ABOUT_CREATOR_VALUES,
  ABOUT_LICENCES,
  ABOUT_PRINCIPLES,
  ABOUT_PURPOSE,
  ABOUT_SOURCE_URL,
  ABOUT_SUPPORT_EMAIL,
  ABOUT_VERSIONS,
  type AboutNote,
} from '../content/about';

function Notes({ heading, notes }: { heading: string; notes: AboutNote[] }) {
  if (notes.length === 0) return null;
  return (
    <>
      <p><strong>{heading}</strong></p>
      <ul>
        {notes.map((n) => (
          <li key={n.title}>
            <strong>{n.title}.</strong> {n.body}
          </li>
        ))}
      </ul>
    </>
  );
}

/** The same words as the About screen in the app (content/about.ts, checked by scripts/check-about-content.mjs). */
export default function About() {
  return (
    <Page route="/about" title="About Anchor" meta="The same note as inside the app">
      <p>{ABOUT_PURPOSE}</p>

      <h2>What it holds to</h2>
      <ul>
        {ABOUT_PRINCIPLES.map((p) => (
          <li key={p}>{p}</li>
        ))}
      </ul>
      <p>
        The longer version is on the <Link to="/philosophy">philosophy</Link> page, and what each part does is on the <Link to="/features">features</Link> page.
      </p>

      <h2>About the creator</h2>
      <p><strong>{ABOUT_CREATOR_NAME}</strong></p>
      {ABOUT_CREATOR_INTRO.map((p) => (
        <p key={p}>{p}</p>
      ))}
      <p>{ABOUT_CREATOR_LINE}</p>
      <p>{ABOUT_CREATOR_VALUES}</p>
      <details>
        <summary>The longer story</summary>
        {ABOUT_CREATOR_STORY.map((n) => (
          <p key={n.title}>
            <strong>{n.title}.</strong> {n.body}
          </p>
        ))}
      </details>
      <p>{ABOUT_CREATOR_CONTACT}</p>
      <p>
        My website is <a href={ABOUT_CREATOR_SITE_URL}>{ABOUT_CREATOR_SITE_URL.replace('https://', '')}</a>.
      </p>

      <h2>What&rsquo;s new</h2>
      {ABOUT_VERSIONS.map((v, i) => (
        <details key={v.version} open={i === 0}>
          <summary>Version {v.version}</summary>
          <Notes heading="Added" notes={v.added} />
          <Notes heading="Changed" notes={v.changed} />
          <Notes heading="Removed" notes={v.removed} />
        </details>
      ))}

      <h2>Licences</h2>
      <p>{ABOUT_LICENCES}</p>

      <h2>Contact</h2>
      <p>
        Email <a href={`mailto:${ABOUT_SUPPORT_EMAIL}`}>{ABOUT_SUPPORT_EMAIL}</a>, or see the <Link to="/support">support page</Link>. {ABOUT_CONTACT_NOTE}
      </p>
      <p>
        The source is at <a href={ABOUT_SOURCE_URL}>{ABOUT_SOURCE_URL.replace('https://', '')}</a>. How Anchor treats your data is in the <Link to="/privacy">privacy policy</Link>.
      </p>
    </Page>
  );
}
