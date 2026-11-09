import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Page } from '../components/Page';
import guide from '../content/guide.generated.json';

type Entry = (typeof guide.entries)[number];

const GROUPS = [
  ...guide.tabs.map((t) => ({ id: t.id, name: t.name, summary: t.summary, paragraphs: t.paragraphs, entries: guide.entries.filter((e) => e.tab === t.id) })),
  { id: 'settings-group', name: 'Settings', summary: '', paragraphs: [] as string[], entries: guide.entries.filter((e) => e.tab === null) },
];

function EntryView({ entry }: { entry: Entry }) {
  return (
    <details id={entry.id}>
      <summary>{entry.title}</summary>
      <p>{entry.whatItIs}</p>
      {entry.howToUse.map((p) => (
        <p key={p}>{p}</p>
      ))}
      {entry.tips.length > 0 && (
        <ul>
          {entry.tips.map((t) => (
            <li key={t}>{t}</li>
          ))}
        </ul>
      )}
    </details>
  );
}

/** Made from the guide inside the app (scripts/sync-guide.mjs), so the two say the same thing. */
export default function Features() {
  useEffect(() => {
    const open = () => {
      const id = decodeURIComponent(window.location.hash.slice(1));
      const el = id ? document.getElementById(id) : null;
      if (el instanceof HTMLDetailsElement) el.open = true;
    };
    open();
    window.addEventListener('hashchange', open);
    return () => window.removeEventListener('hashchange', open);
  }, []);

  return (
    <Page route="/features" title="Features" meta="What each part of Anchor is for">
      <p>
        Anchor has five tabs, and each one keeps a few things in one place. This page is made from the guide inside the app, so it says what the app says. Everything here is optional, and nothing in Anchor is scored.
      </p>
      <p>
        {GROUPS.map((g, i) => (
          <span key={g.id}>
            {i > 0 && ', '}
            <a href={`#${g.id}`}>{g.name}</a>
          </span>
        ))}
        . To see the reasons behind the way it works, read the <Link to="/philosophy">philosophy</Link>.
      </p>

      {GROUPS.map((g) => (
        <section key={g.id}>
          <h2 id={g.id}>{g.name}</h2>
          {g.summary && <p><strong>{g.summary}</strong></p>}
          {g.paragraphs.map((p) => (
            <p key={p}>{p}</p>
          ))}
          {g.entries.map((e) => (
            <EntryView key={e.id} entry={e} />
          ))}
        </section>
      ))}
    </Page>
  );
}
