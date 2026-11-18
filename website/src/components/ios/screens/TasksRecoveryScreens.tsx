import { useState, type ReactNode } from 'react';
import { Card, Glyph, MenuRow, SecondaryButton, TaskCardView } from '../AnchorUI';
import type { DetailParts } from './ListScreens';
import { recoveryHome, taskScreen, type TaskCardData } from '../../../content/seed';

/** RecoveryHomeView */
export function useRecovery(): DetailParts {
  const counters = recoveryHome();
  return {
    title: 'Recovery', toolbar: { trailing: ['gearshape', 'questionmark.circle'] }, inset: 10,
    body: (
      <>
        <div className="au-recovery-hero">Your own counters, kept on this phone. Nothing here is scored, shared or compared.</div>
        <Card tint="sage"><MenuRow icon="wind" title="Riding out an urge" subtitle="A timer, your reasons, and your grounding tools" tint="sage" /></Card>
        {counters.map((c) => (
          <Card key={c.name}>
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
