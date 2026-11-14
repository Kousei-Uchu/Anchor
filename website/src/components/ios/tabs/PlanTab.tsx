import type { ReactNode } from 'react';
import { Card, Glyph, SecondaryButton, Widget, WidgetBig, WidgetCaption } from '../AnchorUI';
import WidgetStackView, { widgetTable } from './WidgetStackView';
import { Affirmations, DecisionPresetsCard, DeEscalation, GroundingTools, QuickContacts } from '../cards';
import { appointmentWidget, motivationsSummary, recoveryWidget, safetyGlance, soonestTriggerWindow, tasksSummary } from '../../../content/seed';

/**
 * The Plan tab: PlanView.swift's widgets, laid out by WidgetStackView.
 */
const widgets = widgetTable;

const Pair = ({ big, caption }: { big: string; caption: string }) => (
  <div className="au-stack-2"><WidgetBig text={big} /><WidgetCaption text={caption} lines={1} /></div>
);

function renderWidget(id: string): ReactNode {
  const m = widgets[id];
  switch (id) {
    case 'safetyPlan': {
      const glance = safetyGlance();
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint} footer={<div><SecondaryButton><Glyph name="shield" size={17} weight={1.8} />Open plan</SecondaryButton></div>}>
          {glance.length === 0 ? <WidgetCaption text="Not filled in yet. Tap to write yours." /> : (
            <div className="au-stack-6">{glance.map((g) => (
              <div key={g.title} className="au-stack-1"><span className="au-caption2 au-secondary">{g.title}</span><span className="au-subheadline au-clamp2">{g.line}</span></div>
            ))}</div>
          )}
        </Widget>
      );
    }
    case 'triggerWindows': {
      const next = soonestTriggerWindow();
      return <Widget icon={m.icon} title={m.title} tint={m.tint}>{next ? <Pair big={next.when} caption={next.label || 'Trigger window'} /> : <WidgetCaption text="None yet. Tap to add one." />}</Widget>;
    }
    case 'appointments': {
      const next = appointmentWidget();
      return <Widget icon={m.icon} title={m.title} tint={m.tint}>{next ? <Pair big={next.when} caption={next.caption} /> : <WidgetCaption text="Nothing scheduled. Tap to set one up." />}</Widget>;
    }
    case 'tasks': {
      const t = tasksSummary();
      return <Widget icon={m.icon} title={m.title} tint={m.tint}>{t ? <Pair big={`${t.count} to do`} caption={t.first} /> : <WidgetCaption text="Nothing here yet. Tap to add something small." />}</Widget>;
    }
    case 'contacts':
      return <Card><div className="au-stack-10"><QuickContacts /><div><SecondaryButton><Glyph name="person.2.fill" size={17} />All contacts</SecondaryButton></div></div></Card>;
    case 'deEscalation':
      return <Card tint="sage"><div className="au-stack-10"><DeEscalation /><div><SecondaryButton tint="sage"><Glyph name="wind" size={17} />All scripts</SecondaryButton></div></div></Card>;
    case 'grounding':
      return <Card tint="sage"><div className="au-stack-10"><GroundingTools /><div><SecondaryButton tint="sage"><Glyph name="leaf.fill" size={17} />All tools</SecondaryButton></div></div></Card>;
    case 'decisionPresets':
      return <DecisionPresetsCard />;
    case 'affirmations':
      return <Card><div className="au-stack-10"><Affirmations /><div><SecondaryButton><Glyph name="sparkles" size={17} />All affirmations</SecondaryButton></div></div></Card>;
    case 'recovery': {
      const r = recoveryWidget();
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint} footer={<div><SecondaryButton tint="sage">Ride out urge</SecondaryButton></div>}>
          {r ? <Pair big={r.big} caption={r.name} /> : <WidgetCaption text="Start a counter whenever you're ready." />}
        </Widget>
      );
    }
    case 'motivations': {
      const s = motivationsSummary();
      return <Widget icon={m.icon} title={m.title} tint={m.tint}>{s ? <Pair big={`${s.count} ${s.count === 1 ? 'reason' : 'reasons'}`} caption={s.first} /> : <WidgetCaption text="Add the people and reasons that matter." />}</Widget>;
    }
    default:
      return null;
  }
}

export default function PlanTab() {
  return <WidgetStackView tab="plan" render={(id) => renderWidget(id)} />;
}
