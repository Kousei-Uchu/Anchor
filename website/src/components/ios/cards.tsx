import { useState } from 'react';
import { Card, ContactChip, Divider, Glyph, HScroll, PresetChip, QuoteBox, RecoveryRow, RoutineChip, SecondaryButton, SectionHeader, TaskRow, ToolRow } from './AnchorUI';
import {
  affirmations, daysUntilLabel, deEscalationScripts, decisionPresets, formatAppointment, groundingTools, messageStarters, nextAppointment,
  demoNow, openTasks, quickContacts, recoveryCounters,
} from '../../content/seed';

/** The cards the Now tab and the Plan widgets share. Each one mirrors the SwiftUI view of the same name. */

/** QuickContactsView (the caller supplies the Card, as NowView and ContactsWidget do) */
export function QuickContacts() {
  const contacts = quickContacts();
  const [contact, setContact] = useState(contacts[0]);
  return (
    <div className="au-stack-10">
      <SectionHeader icon="message.fill" title="Quick contact" />
      <div className="au-chips" style={{ marginTop: 0 }}>
        {contacts.map((n) => <ContactChip key={n} name={n} selected={contact === n} onClick={() => setContact(n)} />)}
      </div>
      <HScroll>
        <SecondaryButton>Just checking in</SecondaryButton>
        {messageStarters().map((t) => <SecondaryButton key={t}><span className="au-nowrap-clip">{t}</span></SecondaryButton>)}
      </HScroll>
    </div>
  );
}

/** RecoveryNowCard */
export function RecoveryNowCard() {
  const counters = recoveryCounters();
  if (counters.length === 0) return null;
  return (
    <Card tint="sage">
      <div className="au-stack-12">
        <SectionHeader icon="calendar.badge.checkmark" title="Recovery" tint="sage" />
        {counters.slice(0, 3).map((c, i) => (
          <div key={c.name} className="au-stack-12">
            {i > 0 && <Divider />}
            <RecoveryRow name={c.name} line={c.line} number={c.number} label={c.label} />
          </div>
        ))}
        <div><SecondaryButton><Glyph name="wind" size={17} />Ride out an urge</SecondaryButton></div>
      </div>
    </Card>
  );
}

/** NextAppointmentCardView */
export function NextAppointmentCard() {
  const now = demoNow();
  const appointment = nextAppointment(now);
  if (!appointment) return null;
  return (
    <Card>
      <div className="au-shortcut">
        <div style={{ flex: 1 }}>
          <SectionHeader icon="calendar.badge.clock" title="Next appointment" />
          <div className="au-subheadline" style={{ marginTop: 2 }}>{appointment.name} · {formatAppointment(appointment.date)}</div>
          <div className="au-caption au-secondary">{daysUntilLabel(appointment.date, now)}</div>
        </div>
        <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
      </div>
    </Card>
  );
}

/** DecisionPresetsQuickView (it draws its own Card) */
export function DecisionPresetsCard() {
  const presets = decisionPresets();
  if (presets.picks.length === 0 && presets.routines.length === 0) return null;
  return (
    <Card>
      <div className="au-stack-10">
        <div className="au-row-between"><SectionHeader icon="checklist" title="Decision presets" /><span className="au-link">See all</span></div>
        {presets.picks.length > 0 && <HScroll>{presets.picks.map((p) => <PresetChip key={p.category} category={p.category} name={p.name} />)}</HScroll>}
        {presets.routines.length > 0 && <HScroll>{presets.routines.map((r) => <RoutineChip key={r} name={r} />)}</HScroll>}
        <div className="au-caption2 au-secondary">One less thing to decide right now. Tap a category's top pick, run a routine, or see all your options.</div>
      </div>
    </Card>
  );
}

/** GroundingToolsView */
export function GroundingTools() {
  return (
    <div className="au-stack-10">
      <SectionHeader icon="leaf.fill" title="Grounding tools" tint="sage" />
      <div className="au-stack-8">{groundingTools().map((t) => <ToolRow key={t} title={t} />)}</div>
    </div>
  );
}

const SHOWN_TASKS = 4;
/** TasksNowCard */
export function TasksNow() {
  const [done, setDone] = useState<string[]>([]);
  const [added, setAdded] = useState<{ id: string; title: string }[]>([]);
  const [draft, setDraft] = useState('');
  const open = [...openTasks(), ...added].filter((t) => !done.includes(t.id));
  const addTask = () => {
    const title = draft.trim();
    if (!title) return;
    setAdded((a) => [...a, { id: `added-${a.length}`, title }]);
    setDraft('');
  };
  return (
    <div className="au-stack-10">
      <div className="au-row-between">
        <SectionHeader icon="checkmark.circle.fill" title="Tasks" />
        <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
      </div>
      {open.length === 0 && <div className="au-caption au-tertiary" style={{ padding: '4px 0' }}>All ticked off.</div>}
      {open.slice(0, SHOWN_TASKS).map((t) => <TaskRow key={t.id} title={t.title} onDone={() => setDone((d) => [...d, t.id])} />)}
      {open.length > SHOWN_TASKS && <div className="au-caption au-secondary">and {open.length - SHOWN_TASKS} more</div>}
      <div className="au-add-row">
        <input className="au-field" placeholder="Add something small" value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && addTask()} />
        <SecondaryButton onClick={addTask}>Add</SecondaryButton>
      </div>
    </div>
  );
}

/** DeEscalationCardView */
export function DeEscalation() {
  const scripts = deEscalationScripts();
  const [i, setI] = useState(0);
  return (
    <div className="au-stack-8">
      <SectionHeader icon="wind" title="De-escalation script" tint="sage" />
      <QuoteBox tint="sage">{'\u201C'}{scripts[i % scripts.length]}{'\u201D'}</QuoteBox>
      {scripts.length > 1 && <div><SecondaryButton tint="sage" onClick={() => setI((n) => n + 1)}>Try another</SecondaryButton></div>}
    </div>
  );
}

/** AffirmationsCardView */
export function Affirmations() {
  const lines = affirmations();
  const [i, setI] = useState(0);
  return (
    <div className="au-stack-8">
      <SectionHeader icon="sparkles" title="Something to hold onto" />
      <QuoteBox italic>{lines[i % lines.length]}</QuoteBox>
      {lines.length > 1 && <div><SecondaryButton onClick={() => setI((n) => n + 1)}>Another</SecondaryButton></div>}
    </div>
  );
}
