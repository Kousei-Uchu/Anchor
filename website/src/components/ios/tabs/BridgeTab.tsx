import { useState, type ReactNode } from 'react';
import { Card, Glyph, RaiseRow, SecondaryButton, Widget, WidgetBig, WidgetCaption } from '../AnchorUI';
import WidgetStackView from './WidgetStackView';
import { feedbackLoopsSummary, nextSessionCaption, personalGoalsSummary, thingsToRaise } from '../../../content/seed';

/** The Bridge tab: BridgeView's widgets, laid out by WidgetStackView. */
function ThingsToRaise({ icon, title, tint }: { icon: string; title: string; tint: 'accent' | 'sage' }) {
  const [resolved, setResolved] = useState<string[]>([]);
  const open = thingsToRaise().filter((i) => !resolved.includes(i.id));
  return (
    <Widget icon={icon} title={title} tint={tint}
      footer={<div className="au-stack-6">{open.slice(0, 3).map((i) => <RaiseRow key={i.id} text={i.text} onToggle={() => setResolved((r) => [...r, i.id])} />)}</div>}>
      <WidgetCaption lines={1} text={open.length === 0 ? 'Nothing queued. Tap to add something for your next session.' : `${open.length} for your next session`} />
    </Widget>
  );
}

function render(id: string, m: { title: string; icon: string; tint: 'accent' | 'sage' }): ReactNode {
  switch (id) {
    case 'thingsToRaise':
      return <ThingsToRaise icon={m.icon} title={m.title} tint={m.tint} />;
    case 'nextSession':
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint}
          footer={<div className="au-btn-row"><SecondaryButton>Session prep</SecondaryButton><SecondaryButton>After session</SecondaryButton></div>}>
          <WidgetCaption lines={1} text={nextSessionCaption()} />
        </Widget>
      );
    case 'reframing':
      return (
        <Card tint="sage">
          <div className="au-widget-main" style={{ ['--tint' as string]: 'var(--anchor-sage)' }}>
            <div className="au-widget-head">
              <span className="au-badge au-badge-circle au-badge-sm"><Glyph name={m.icon} size={15} /></span>
              <span className="au-subheadline au-semibold au-widget-title">{m.title}</span>
            </div>
            <WidgetCaption text="Stuck on a thought? Try a reframe." />
          </div>
        </Card>
      );
    case 'feedbackLoops': {
      const f = feedbackLoopsSummary();
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint}>
          {f ? <div className="au-stack-2"><WidgetBig text={`${f.count} ${f.count === 1 ? 'diagram' : 'diagrams'}`} /><WidgetCaption text={f.latest} lines={1} /></div> : <WidgetCaption text="Map a pattern you keep seeing." />}
        </Widget>
      );
    }
    case 'personalGoals': {
      const g = personalGoalsSummary();
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint}>
          {g ? <div className="au-stack-1"><span className="au-subheadline au-clamp2">{g.first}</span>{g.more > 0 && <span className="au-caption2 au-secondary">and {g.more} more</span>}</div> : <WidgetCaption text="Your own goals, in your own words. Tap to add one." />}
        </Widget>
      );
    }
    default:
      return null;
  }
}

export default function BridgeTab() {
  return <WidgetStackView tab="bridge" render={render} />;
}
