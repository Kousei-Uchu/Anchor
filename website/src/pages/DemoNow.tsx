import { AnchorScreen, Card, EmptyState, Glyph, MenuRow, PrimaryButton, SectionHeader, Tile, TileRow } from '../components/ios/AnchorUI';
import demo from '../content/demo.generated.json';

/**
 * Development preview of the Now tab, built from the app's design system (not screenshots).
 * Only reachable while running `npm run dev`, at /demo-now. Add ?dark to see dark mode.
 * The text comes from demo.generated.json, which scripts/sync-demo.mjs reads out of the Swift source.
 */
const TOOL_ICONS = ['eye', 'hand', 'wind', 'leaf', 'heart'];

export default function DemoNow() {
  const dark = new URLSearchParams(window.location.search).has('dark');
  const tools = demo.tools as { title: string }[];
  const affirmation = (demo.affirmations as string[])[0];
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '24px 0 64px' }}>
      <AnchorScreen title="Now" scheme={dark ? 'dark' : 'light'}>
        <PrimaryButton><Glyph name="hex" size={15} weight={2.4} />Check in</PrimaryButton>

        <Card>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <SectionHeader icon="calendar" title="Next appointment" />
              <div className="au-subheadline" style={{ marginTop: 2 }}>Psychologist · Tomorrow, 2:30 pm</div>
              <div className="au-caption au-secondary">Tomorrow</div>
            </div>
            <span className="au-tertiary"><Glyph name="chevron" size={14} weight={2.6} /></span>
          </div>
        </Card>

        <Card tint="sage">
          <SectionHeader icon="leaf" title="Grounding" tint="sage" />
          <div style={{ marginTop: 12 }}>
            <TileRow title="Tools">
              {tools.map((t, i) => <Tile key={t.title} icon={TOOL_ICONS[i % TOOL_ICONS.length]} title={t.title} tint="sage" />)}
            </TileRow>
          </div>
        </Card>

        <Card>
          <SectionHeader icon="heart" title="Affirmations" />
          <div className="au-body" style={{ marginTop: 10 }}>{affirmation}</div>
        </Card>

        <Card>
          <MenuRow icon="check" title="Tasks" subtitle="Nothing due today" />
        </Card>

        <EmptyState icon="leaf" title="Nothing to catch up on" message="This page only shows what you ask it to." actionTitle="Add something" />
      </AnchorScreen>
    </div>
  );
}
