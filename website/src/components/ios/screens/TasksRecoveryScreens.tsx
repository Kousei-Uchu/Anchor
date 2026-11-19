import { useEffect, useState, type ReactNode } from 'react';
import { Card, Glyph, MenuRow, SecondaryButton, TaskCardView } from '../AnchorUI';
import type { DetailParts } from './ListScreens';
import { useNav } from '../nav';
import { counterDetail, recoveryHome, taskScreen, type TaskCardData } from '../../../content/seed';

/** RecoveryHomeView */
export function useRecovery(): DetailParts {
  const nav = useNav();
  const counters = recoveryHome();
  return {
    title: 'Recovery', toolbar: { trailing: ['gearshape', 'questionmark.circle'] }, inset: 10,
    body: (
      <>
        <div className="au-recovery-hero">Your own counters, kept on this phone. Nothing here is scored, shared or compared.</div>
        <Card tint="sage"><MenuRow icon="wind" title="Riding out an urge" subtitle="A timer, your reasons, and your grounding tools" tint="sage" /></Card>
        {counters.map((c) => (
          <Card key={c.name} onClick={() => nav.push(`counter::${c.name}`)}>
            <div className="au-listcard">
              <div className="au-listcard-main" style={{ gap: 4 }}>
                <span className="au-headline">{c.name}</span>
                {c.showTotal && <span className="au-caption au-secondary">{c.total} {c.total === 1 ? 'day' : 'days'} in total</span>}
                <span className="au-caption au-secondary">{c.next}</span>
              </div>
              <div className="au-recovery-num"><span className="au-recovery-big40">{c.number}</span><span className="au-caption au-secondary">{c.label}</span></div>
            </div>
          </Card>
        ))}
        <div className="au-center-row"><SecondaryButton><Glyph name="plus" size={18} weight={2.4} />Add a counter</SecondaryButton></div>
        <Card><MenuRow icon="heart.fill" title="Who I'm doing this for" subtitle="People and reasons, in your own words" /></Card>
      </>
    ),
  };
}

/** TasksView: quick lists, tasks grouped by when they are due, then done. Ticking a ring moves a task to Done; the field adds one with no date. */
export function useTasks(): DetailParts {
  const base = taskScreen();
  const [completed, setCompleted] = useState<string[]>([]);
  const [expanded, setExpanded] = useState<string[]>([]);
  const [added, setAdded] = useState<TaskCardData[]>([]);
  const [draft, setDraft] = useState('');
  const toggleDone = (id: string) => setCompleted((c) => (c.includes(id) ? c.filter((x) => x !== id) : [...c, id]));
  const toggleSteps = (id: string) => setExpanded((e) => (e.includes(id) ? e.filter((x) => x !== id) : [...e, id]));
  const addTask = () => {
    const title = draft.trim();
    if (!title) return;
    setAdded((a) => [...a, { id: `added-${a.length}`, title, done: false, facts: [], steps: [] }]);
    setDraft('');
  };

  const isDone = (t: TaskCardData) => t.done !== completed.includes(t.id);
  const every = [...base.buckets.flatMap((b) => b.tasks.map((t) => ({ bucket: b.title, t }))), ...added.map((t) => ({ bucket: 'No date', t })), ...base.done.map((t) => ({ bucket: 'Done', t }))];
  const titles = ['Today', 'This week', 'Later', 'No date', 'Waiting on something else', 'Set aside for now'];
  const open = titles.map((title) => ({ title, tasks: every.filter((x) => x.bucket === title && !isDone(x.t)).map((x) => x.t) })).filter((g) => g.tasks.length > 0);
  const done = every.filter((x) => isDone(x.t)).map((x) => x.t);
  const card = (t: TaskCardData): ReactNode => (
    <TaskCardView key={t.id} {...t} done={isDone(t)} expanded={expanded.includes(t.id)} onToggleDone={() => toggleDone(t.id)} onToggleSteps={() => toggleSteps(t.id)} />
  );

  return {
    title: 'Tasks', toolbar: { trailing: ['questionmark.circle', 'text:Reorder', 'ellipsis.circle', 'plus'] }, inset: 18,
    bottomBar: (
      <div className="au-addbar">
        <input className="au-field" placeholder="Add a task" value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && addTask()} />
        <SecondaryButton onClick={addTask}>Add</SecondaryButton>
        <button type="button" className="au-iconbtn" aria-label="Add several"><Glyph name="list.bullet.rectangle" size={28} weight={1.6} /></button>
      </div>
    ),
    body: (
      <>
        {base.quickLists.length > 0 && (
          <>
            <div className="au-tasks-label"><span>Quick lists</span><button type="button">New</button></div>
            {base.quickLists.map((l) => (
              <Card key={l.title}>
                <div className="au-listcard">
                  <span className="au-accent"><Glyph name="list.clipboard" size={34} weight={1.4} /></span>
                  <div className="au-listcard-main" style={{ gap: 2 }}><span className="au-body">{l.title}</span><span className="au-caption au-secondary">{l.ticked} of {l.total} ticked</span></div>
                  <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
                </div>
              </Card>
            ))}
          </>
        )}
        {open.map((g) => (<div key={g.title} className="au-stack-16"><div className="au-tasks-label"><span>{g.title}</span></div>{g.tasks.map(card)}</div>))}
        {done.length > 0 && <div className="au-stack-16"><div className="au-tasks-label"><span>Done</span><button type="button">Clear done</button></div>{done.map(card)}</div>}
        {base.archivedLists > 0 && (
          <Card><div className="au-listcard"><span className="au-secondary"><Glyph name="archivebox" size={28} weight={1.5} /></span><span className="au-body au-grow" style={{ textAlign: 'left' }}>Archive</span><span className="au-secondary">{base.archivedLists}</span><span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span></div></Card>
        )}
        <div style={{ height: 70 }} />
      </>
    ),
  };
}


const DAY_MS = 86_400_000;

/** The counter's rings: seconds on the outside, then progress toward the next milestone, with the counter's name in the middle. */
function CounterRings({ seconds, dayProgress, name }: { seconds: number; dayProgress: number; name: string }) {
  const arc = (r: number, frac: number) => { const a = Math.max(0.0001, Math.min(frac, 0.9999)) * 2 * Math.PI - Math.PI / 2; const x = 67 + r * Math.cos(a), y = 67 + r * Math.sin(a); return `M 67 ${67 - r} A ${r} ${r} 0 ${frac > 0.5 ? 1 : 0} 1 ${x} ${y}`; };
  return (
    <svg className="au-rings" width="150" height="150" viewBox="0 0 134 134" aria-hidden="true">
      {[62, 54, 46, 38].map((r) => <circle key={r} cx="67" cy="67" r={r} fill="none" stroke="rgb(120 120 128 / 0.12)" strokeWidth="5" />)}
      <path d={arc(62, seconds / 60)} fill="none" stroke="var(--anchor-accent)" strokeWidth="5" strokeLinecap="round" />
      <path d={arc(46, dayProgress)} fill="none" stroke="var(--anchor-sage)" strokeWidth="5" strokeLinecap="round" />
      <circle cx="67" cy="67" r="27" fill="url(#au-disc)" />
      <defs><linearGradient id="au-disc" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="var(--anchor-accent)" stopOpacity="0.9" /><stop offset="1" stopColor="var(--anchor-accent)" stopOpacity="0.6" /></linearGradient></defs>
      <text x="67" y="65" textAnchor="middle" fontSize="8.5" fontWeight="600" fill="#fff">{name.split(' ')[0]}</text>
      <text x="67" y="75" textAnchor="middle" fontSize="8.5" fontWeight="600" fill="#fff">{name.split(' ').slice(1).join(' ')}</text>
    </svg>
  );
}

/** A counter's detail screen: the Summary page with the time on this run counting up as you watch. The other pages are not rebuilt. */
export function useCounter(name?: string): DetailParts {
  const c = counterDetail(name ?? '');
  const [mounted] = useState(() => Date.now());
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => { const id = window.setInterval(() => setNow(Date.now()), 1000); return () => window.clearInterval(id); }, []);
  const elapsed = (c?.days ?? 0) * DAY_MS + (now - mounted);
  const days = Math.floor(elapsed / DAY_MS), hours = Math.floor(elapsed / 3_600_000) % 24, minutes = Math.floor(elapsed / 60_000) % 60, seconds = Math.floor(elapsed / 1000) % 60;
  const tabs = ['Summary', 'Savings', 'Calendar', 'Urges', 'Reasons'];
  return {
    title: c?.name ?? 'Counter', toolbar: { trailing: ['questionmark.circle', 'gearshape'] }, inset: 20,
    pinned: <div className="au-tabsrow">{tabs.map((t, i) => <span key={t} className={`au-tabchip${i === 0 ? ' au-tabchip-on' : ''}`}>{t}</span>)}</div>,
    body: !c ? null : (
      <>
        <div className="au-subheadline au-secondary au-center" style={{ paddingTop: 48 }}>Time on this run</div>
        <Card>
          <div className="au-counter">
            <div className="au-counter-nums">
              {[[days, 'days', 'var(--anchor-sage)'], [hours, 'hours', 'color-mix(in srgb, var(--anchor-accent) 40%, var(--anchor-sage))'], [minutes, 'minutes', 'color-mix(in srgb, var(--anchor-accent) 70%, var(--anchor-sage))'], [seconds, 'seconds', 'var(--anchor-accent)']].map(([v, label, color]) => (
                <div key={String(label)} className="au-counter-row"><span className="au-counter-num" style={{ color: String(color) }}>{v}</span><span className="au-subheadline au-secondary">{label}</span></div>
              ))}
            </div>
            <CounterRings seconds={seconds} dayProgress={c.days / c.next} name={c.name} />
          </div>
        </Card>
        <div className="au-dots">{[0, 1, 2, 3, 4, 5].map((i) => <i key={i} className={i === 0 ? 'on' : ''} />)}</div>
        <div className="au-actions">
          <span><Glyph name="square.and.arrow.up" size={26} weight={1.6} />Share</span>
          <span><Glyph name="waveform" size={26} weight={1.6} />Log urge</span>
          <span><Glyph name="arrow.counterclockwise" size={26} weight={1.6} />Start again</span>
        </div>
      </>
    ),
  };
}
