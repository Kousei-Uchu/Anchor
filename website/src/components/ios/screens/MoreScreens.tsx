import { Card, Glyph, ListCard, NavRow, SecondaryButton, SectionHeader } from '../AnchorUI';
import { useNav } from '../nav';
import type { DetailParts } from './ListScreens';
import {
  boundaryCards, calendarEntries, diagramRows, futureNoteRows, goalGroups, messageLog, peopleRows, safetyPlan, unsentDraftRows, writeToNames,
} from '../../../content/seed';

/** Pushed screens for People, To future me, Personal goals, Feedback loops, Boundaries, Support calendar, Message log and the Safety plan. */
const HELP_ADD = ['questionmark.circle', 'plus'];
const Chev = () => <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>;

/** PeopleScreen */
export function usePeople(): DetailParts {
  return {
    title: 'People', toolbar: { trailing: ['questionmark.circle'] }, inset: 18,
    body: <>{peopleRows().map((p) => (
      <NavRow key={p.name}>
        <span className="au-icon-badge"><Glyph name="person.crop.circle.fill" size={30} /></span>
        <div className="au-listcard-main" style={{ gap: 2 }}><span className="au-headline">{p.name}</span><span className="au-subheadline au-secondary">{p.summary}</span></div>
      </NavRow>
    ))}</>,
  };
}

/** FutureNotesView */
export function useFutureNotes(): DetailParts {
  const { dated, letters } = futureNoteRows();
  return {
    title: 'To future me', toolbar: { trailing: HELP_ADD }, inset: 18,
    body: (
      <>
        {dated.map((n, i) => (
          <ListCard key={i} small title={n.title} subtitle={n.subtitle} accessory={<span className="au-secondary"><Glyph name={n.locked ? 'lock' : 'envelope'} size={24} weight={1.6} /></span>} />
        ))}
        {letters.length > 0 && <div className="au-section-label-sm">Letters to open when you choose</div>}
        {letters.map((n, i) => <ListCard key={i} small title={n.title} subtitle={n.subtitle} accessory={<span className="au-secondary"><Glyph name="envelope" size={24} weight={1.6} /></span>} />)}
      </>
    ),
  };
}

/** PersonalGoalsView */
export function usePersonalGoals(): DetailParts {
  const { working, reached } = goalGroups();
  return {
    title: 'Personal goals', toolbar: { trailing: HELP_ADD }, inset: 18,
    body: (
      <>
        {working.map((g) => (
          <Card key={g.title}>
            <div className="au-listcard-main" style={{ gap: 4 }}>
              <span className="au-headline">{g.title}</span>
              {g.why && <span className="au-subheadline au-secondary">{g.why}</span>}
              {g.meta && <span className="au-row-meta">{g.meta}</span>}
            </div>
          </Card>
        ))}
        {reached.length > 0 && <div className="au-section-label">Reached</div>}
        {reached.map((g) => <Card key={g.title}><div className="au-headline au-secondary" style={{ textAlign: 'left' }}>{g.title}</div></Card>)}
      </>
    ),
  };
}

/** FeedbackLoopDiagramView's list */
export function useFeedbackLoops(): DetailParts {
  const nav = useNav();
  return {
    title: 'Feedback-loop diagrams', toolbar: { trailing: HELP_ADD }, inset: 18,
    body: <>{diagramRows().map((d) => (
      <Card key={d.title} onClick={d.loop ? () => nav.push(`loop::${d.title}`) : undefined}><div className="au-listcard"><div className="au-listcard-main" style={{ gap: 2 }}><span className="au-headline">{d.title}</span><span className="au-caption au-secondary">{d.summary}</span></div><Chev /></div></Card>
    ))}</>,
  };
}

function PlanSectionCard({ icon, title, tint, lines, shareable }: { icon: string; title: string; tint: 'accent' | 'sage'; lines: string[]; shareable?: boolean }) {
  return (
    <Card tint={tint}>
      <div className="au-card-rel">
        <div className="au-corner">{shareable && <Glyph name="square.and.arrow.up" size={20} weight={1.8} />}<Glyph name="pencil" size={20} weight={1.8} /></div>
        <div className="au-stack-12">
          <SectionHeader icon={icon} title={title} tint={tint} />
          <div className="au-lines">{lines.map((l, i) => <span key={i}>{l}</span>)}</div>
        </div>
      </div>
    </Card>
  );
}

/** BoundariesView */
export function useBoundaries(): DetailParts {
  return {
    title: 'Boundaries', toolbar: { trailing: ['questionmark.circle', 'square.and.arrow.up', 'text:Reorder', 'plus'] }, inset: 18,
    body: <>{boundaryCards().map((b) => <PlanSectionCard key={b.title} icon={b.icon} title={b.title} tint={b.tint} lines={b.text.split('\n').filter(Boolean)} shareable={b.shareable} />)}</>,
  };
}

/** SafetyPlanEditorView */
export function useSafetyPlan(): DetailParts {
  const { sections, updated } = safetyPlan();
  return {
    title: 'Safety plan', toolbar: { trailing: ['questionmark.circle', 'text:Reorder', 'plus'] }, inset: 18,
    body: <>{sections.map((s) => <PlanSectionCard key={s.title} icon={s.icon} title={s.title} tint={s.tint} lines={s.lines} />)}<div className="au-updated">{updated}</div></>,
  };
}

/** SupportCalendarView */
export function useSupportCalendar(): DetailParts {
  return {
    title: 'Support calendar', toolbar: { trailing: HELP_ADD }, inset: 18,
    body: (
      <>
        <Card>
          <div className="au-listcard">
            <span className="au-badge au-badge-square"><Glyph name="square.and.arrow.up" size={20} weight={1.8} /></span>
            <div className="au-listcard-main" style={{ gap: 2 }}><span className="au-body au-medium">Share with...</span><span className="au-caption au-secondary">Sends a real calendar file, they don't need Anchor</span></div>
          </div>
        </Card>
        {calendarEntries().map((e) => (
          <Card key={e.when + e.note}>
            <div className="au-card-rel">
              <div className="au-corner"><Chev /></div>
              <div className="au-listcard-main" style={{ gap: 4 }}>
                <span className="au-headline">{e.when}</span>
                <span className="au-subheadline au-secondary">{e.note}</span>
                {e.visibleTo && <span className="au-row-meta au-label-plain"><Glyph name="eye" size={17} weight={1.8} />{e.visibleTo}</span>}
              </div>
            </div>
          </Card>
        ))}
      </>
    ),
  };
}

/** ThreadMessagesView */
export function useMessageLog(): DetailParts {
  return {
    title: 'Message log', toolbar: { trailing: ['questionmark.circle', 'text.bubble', 'plus'] }, inset: 20,
    body: (
      <>
        <div className="au-intro">Quick notes tied to a real contact. Sent right away if you want, or just saved as a log of what you've told them over time. For bigger things you might never send, that's "Things I haven't said" instead.</div>
        <div className="au-stack-8">
          <div className="au-minor">Write to</div>
          <div className="au-chips-wrap">{writeToNames().map((n) => <SecondaryButton key={n}><Glyph name="square.and.pencil" size={17} weight={1.8} />{n}</SecondaryButton>)}</div>
        </div>
        <div className="au-filter-row"><span className="au-filter"><Glyph name="line.3.horizontal.decrease.circle" size={20} weight={1.8} />Everyone</span></div>
        {messageLog().map((m) => (
          <Card key={m.when + m.text}>
            <div className="au-card-rel">
              <div className="au-corner"><Chev /></div>
              <div className="au-listcard-main" style={{ gap: 2 }}>
                <span className="au-msg-who">{m.who}</span>
                <span className="au-msg-text">{m.text}</span>
                <span className="au-row-meta">{m.when}</span>
              </div>
            </div>
          </Card>
        ))}
      </>
    ),
  };
}

/** UnsentDraftsView: private notes to people, some sent and some never sent. */
export function useUnsentDrafts(): DetailParts {
  return {
    title: "Things I haven't said", toolbar: { trailing: HELP_ADD }, inset: 18,
    body: <>{unsentDraftRows().map((d) => (
      <Card key={d.to + d.text} tint="sage">
        <div className="au-card-rel">
          <div className="au-corner"><Chev /></div>
          <div className="au-listcard-main" style={{ gap: 4 }}>
            <div className="au-draft-top"><span className="au-headline">{d.to}</span>{d.sent && <span className="au-caption au-secondary au-label-plain"><Glyph name="checkmark" size={16} weight={2.2} />Sent</span>}</div>
            <span className="au-subheadline au-secondary au-clamp2">{d.text}</span>
          </div>
        </div>
      </Card>
    ))}</>,
  };
}
