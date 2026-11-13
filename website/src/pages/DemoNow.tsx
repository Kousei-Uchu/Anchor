import { useState } from 'react';
import {
  AnchorScreen, Card, ContactChip, CrisisCard, Divider, Glyph, HScroll, MascotPresence, PresetChip, PrimaryButton, QuoteBox, RecoveryRow,
  RoutineChip, SecondaryButton, SectionHeader, ShortcutRow, TaskRow, ToolRow,
} from '../components/ios/AnchorUI';
import demo from '../content/demo.generated.json';
import {
  affirmations, daysUntilLabel, deEscalationScripts, decisionPresets, formatAppointment, groundingTools, messageStarters, nextAppointment,
  openTasks, quickContacts, recoveryCounters,
} from '../content/seed';

/**
 * Development preview of the full Now tab, built from the app's design system and the app's own demo data.
 * Only reachable while running `npm run dev`, at /demo-now. Add ?dark for dark mode, ?full to lay the whole screen out without scrolling.
 * Card order follows NowView.swift. The Sleep card is left out because the app only shows it when its setting is on, and the demo does not turn it on.
 */
const NUMBERS = [
  { label: 'Emergency', display: '000', kind: 'call' as const },
  { label: 'Lifeline (call)', display: '13 11 14', kind: 'call' as const },
  { label: 'Lifeline (text)', display: '0477 13 11 14', kind: 'text' as const },
];
const SHOWN_TASKS = 4;

export default function DemoNow() {
  const params = new URLSearchParams(window.location.search);
  const now = new Date();
  const contacts = quickContacts();
  const [contact, setContact] = useState(contacts[0]);
  const [done, setDone] = useState<string[]>([]);
  const [added, setAdded] = useState<{ id: string; title: string }[]>([]);
  const [draft, setDraft] = useState('');
  const [scriptIndex, setScriptIndex] = useState(0);
  const [affirmationIndex, setAffirmationIndex] = useState(0);

  const appointment = nextAppointment(now);
  const counters = recoveryCounters(now);
  const presets = decisionPresets();
  const scripts = deEscalationScripts();
  const lines = affirmations();
  const open = [...openTasks(), ...added].filter((t) => !done.includes(t.id));
  const addTask = () => {
    const title = draft.trim();
    if (!title) return;
    setAdded((a) => [...a, { id: `added-${a.length}`, title }]);
    setDraft('');
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '96px 0 64px' }}>
      <AnchorScreen title="Now" tab="Now" scheme={params.has('dark') ? 'dark' : 'light'} full={params.has('full')}>
        <CrisisCard numbers={NUMBERS} region="Australia" />
        <MascotPresence line={demo.mascot.hello} />
        <PrimaryButton><Glyph name="circle.hexagongrid.fill" size={22} />Check in</PrimaryButton>

        <Card>
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
        </Card>

        {counters.length > 0 && (
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
        )}

        {appointment && (
          <Card>
            <div className="au-shortcut">
              <div style={{ flex: 1 }}>
                <SectionHeader icon="calendar.badge.clock" title="Next appointment" />
                <div className="au-subheadline" style={{ marginTop: 2 }}>{appointment.name} · {formatAppointment(appointment.date)}</div>
                <div className="au-caption au-secondary">{daysUntilLabel(appointment.date, now)}</div>
              </div>
              <span className="au-tertiary"><Glyph name="chevron.right" size={12} weight={2.8} /></span>
            </div>
          </Card>
        )}

        <ShortcutRow icon="shield.fill" title="Open my safety plan" />

        {(presets.picks.length > 0 || presets.routines.length > 0) && (
          <Card>
            <div className="au-stack-10">
              <div className="au-row-between"><SectionHeader icon="checklist" title="Decision presets" /><span className="au-link">See all</span></div>
              {presets.picks.length > 0 && <HScroll>{presets.picks.map((p) => <PresetChip key={p.category} category={p.category} name={p.name} />)}</HScroll>}
              {presets.routines.length > 0 && <HScroll>{presets.routines.map((r) => <RoutineChip key={r} name={r} />)}</HScroll>}
              <div className="au-caption2 au-secondary">One less thing to decide right now. Tap a category's top pick, run a routine, or see all your options.</div>
            </div>
          </Card>
        )}

        <Card tint="sage">
          <div className="au-stack-10">
            <SectionHeader icon="leaf.fill" title="Grounding tools" tint="sage" />
            <div className="au-stack-8">{groundingTools().map((t) => <ToolRow key={t} title={t} />)}</div>
          </div>
        </Card>

        <Card>
          <div className="au-stack-10">
            <div className="au-row-between">
              <SectionHeader icon="checkmark.circle.fill" title="Tasks" />
              <span className="au-tertiary"><Glyph name="chevron.right" size={12} weight={2.8} /></span>
            </div>
            {open.length === 0 && <div className="au-caption au-tertiary" style={{ padding: '4px 0' }}>All ticked off.</div>}
            {open.slice(0, SHOWN_TASKS).map((t) => <TaskRow key={t.id} title={t.title} onDone={() => setDone((d) => [...d, t.id])} />)}
            {open.length > SHOWN_TASKS && <div className="au-caption au-secondary">and {open.length - SHOWN_TASKS} more</div>}
            <div className="au-add-row">
              <input className="au-field" placeholder="Add something small" value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && addTask()} />
              <SecondaryButton onClick={addTask}>Add</SecondaryButton>
            </div>
          </div>
        </Card>

        <Card tint="sage">
          <div className="au-stack-8">
            <SectionHeader icon="wind" title="De-escalation script" tint="sage" />
            <QuoteBox tint="sage">{'\u201C'}{scripts[scriptIndex % scripts.length]}{'\u201D'}</QuoteBox>
            {scripts.length > 1 && <div><SecondaryButton tint="sage" onClick={() => setScriptIndex((i) => i + 1)}>Try another</SecondaryButton></div>}
          </div>
        </Card>

        <Card>
          <div className="au-stack-8">
            <SectionHeader icon="sparkles" title="Something to hold onto" />
            <QuoteBox italic>{lines[affirmationIndex % lines.length]}</QuoteBox>
            {lines.length > 1 && <div><SecondaryButton onClick={() => setAffirmationIndex((i) => i + 1)}>Another</SecondaryButton></div>}
          </div>
        </Card>
      </AnchorScreen>
    </div>
  );
}
