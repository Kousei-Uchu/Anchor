import { useState } from 'react';
import { AnchorScreen, Card, ContactChip, CrisisCard, Glyph, MascotPresence, PrimaryButton, SecondaryButton, SectionHeader, ShortcutRow, ToolRow } from '../components/ios/AnchorUI';
import demo from '../content/demo.generated.json';

/**
 * Development preview of the Now tab, built from the app's design system (not screenshots).
 * Only reachable while running `npm run dev`, at /demo-now. Add ?dark to see dark mode.
 * Grounding tool names and the mascot line come from demo.generated.json, which scripts/sync-demo.mjs reads out of the Swift source.
 * The crisis numbers, contacts and appointment are the values the app shows in demo mode.
 */
const NUMBERS = [
  { label: 'Emergency', display: '000', kind: 'call' as const },
  { label: 'Lifeline (call)', display: '13 11 14', kind: 'call' as const },
  { label: 'Lifeline (text)', display: '0477 13 11 14', kind: 'text' as const },
];

export default function DemoNow() {
  const dark = new URLSearchParams(window.location.search).has('dark');
  const [contact, setContact] = useState('Sam');
  const tools = demo.tools as { title: string }[];
  const line = demo.mascot.hello;
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '96px 0 64px' }}>
      <AnchorScreen title="Now" tab="Now" scheme={dark ? 'dark' : 'light'}>
        <CrisisCard numbers={NUMBERS} region="Australia" />
        <MascotPresence line={line} />
        <PrimaryButton><Glyph name="circle.hexagongrid.fill" size={22} />Check in</PrimaryButton>

        <Card>
          <div className="au-stack-10">
            <SectionHeader icon="message.fill" title="Quick contact" />
            <div className="au-chips" style={{ marginTop: 0 }}>
              {['Sam', 'Alex'].map((n) => <ContactChip key={n} name={n} selected={contact === n} onClick={() => setContact(n)} />)}
            </div>
            <div><SecondaryButton>Just checking in</SecondaryButton></div>
          </div>
        </Card>

        <Card>
          <div className="au-shortcut">
            <div style={{ flex: 1 }}>
              <SectionHeader icon="calendar.badge.clock" title="Next appointment" />
              <div className="au-subheadline" style={{ marginTop: 2 }}>Dr Lee · 10 Nov 2026 at 10:30 am</div>
              <div className="au-caption au-secondary">In 6 days</div>
            </div>
            <span className="au-tertiary"><Glyph name="chevron.right" size={12} weight={2.8} /></span>
          </div>
        </Card>

        <ShortcutRow icon="shield.fill" title="Open my safety plan" />

        <Card tint="sage">
          <div className="au-stack-10">
            <SectionHeader icon="leaf.fill" title="Grounding tools" tint="sage" />
            <div className="au-stack-8">{tools.map((t) => <ToolRow key={t.title} title={t.title} />)}</div>
          </div>
        </Card>
      </AnchorScreen>
    </div>
  );
}
