import type { ReactNode } from 'react';
import { Glyph, SecondaryButton, Widget, WidgetBig, WidgetCaption, WeekStrip } from '../AnchorUI';
import WidgetStackView from './WidgetStackView';
import { boundariesGlance, futureNotesSummary, latestMessage, peopleCaption, supportWeek, unsentDraftCount } from '../../../content/seed';

/** The Thread tab: ThreadView's widgets, laid out by WidgetStackView. */
function render(id: string, m: { title: string; icon: string; tint: 'accent' | 'sage' }): ReactNode {
  switch (id) {
    case 'messageLog': {
      const last = latestMessage();
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint} footer={<div><SecondaryButton><Glyph name="square.and.pencil" size={17} weight={1.8} />Write</SecondaryButton></div>}>
          {last ? <div className="au-stack-2"><WidgetCaption text={last.when} lines={1} /><span className="au-subheadline au-clamp2">{last.text}</span></div> : <WidgetCaption text="Write to someone, or keep a note of what you've told them." />}
        </Widget>
      );
    }
    case 'supportCalendar':
      return <Widget icon={m.icon} title={m.title} tint={m.tint}><WeekStrip days={supportWeek()} /></Widget>;
    case 'people':
      return <Widget icon={m.icon} title={m.title} tint={m.tint}><WidgetCaption text={peopleCaption()} lines={2} /></Widget>;
    case 'futureNotes': {
      const f = futureNotesSummary();
      return <Widget icon={m.icon} title={m.title} tint={m.tint}>{f.big ? <div className="au-stack-2"><WidgetBig text={f.big} /><WidgetCaption text={f.caption} /></div> : <WidgetCaption text={f.caption} />}</Widget>;
    }
    case 'unsentDrafts': {
      const n = unsentDraftCount();
      const caption = 'Private. For big things you might never send.';
      return <Widget icon={m.icon} title={m.title} tint={m.tint}>{n > 0 ? <div className="au-stack-2"><WidgetBig text={`${n} ${n === 1 ? 'draft' : 'drafts'}`} /><WidgetCaption text={caption} /></div> : <WidgetCaption text={caption} />}</Widget>;
    }
    case 'boundaries': {
      const b = boundariesGlance();
      return (
        <Widget icon={m.icon} title={m.title} tint={m.tint}>
          {b ? <div className="au-stack-1"><span className="au-caption2 au-secondary">{b.title}</span><span className="au-subheadline au-clamp2">{b.line}</span></div> : <WidgetCaption text="Not filled in yet. Tap to write yours." />}
        </Widget>
      );
    }
    default:
      return null;
  }
}

export default function ThreadTab() {
  return <WidgetStackView tab="thread" render={render} />;
}
