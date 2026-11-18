import { useState } from 'react';
import { Card, ClinicianPills, Glyph, PrepCard, SecondaryButton, SectionHeader } from '../AnchorUI';
import type { DetailParts } from './ListScreens';
import { bridgeDraftRows, clinicians, postSessions, sessionPrep } from '../../../content/seed';

/** Session prep, Post-session notes and the Bridge draft list. */
const PREP_TOOLBAR = ['questionmark.circle', 'person.crop.circle.fill'];
const NOTE = 'Only shown here. Nothing goes into your notes unless you add it.';

/** AppointmentPrepView: one set of cards per clinician, picked with the pills under the title. */
export function usePrep(): DetailParts {
  const people = clinicians();
  const [id, setId] = useState(people[0]?.id ?? '');
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [bring, setBring] = useState<Record<string, { text: string; done: boolean }[]>>({});
  const [picked, setPicked] = useState<string[]>([]);
  const [chooseOpen, setChooseOpen] = useState(false);
  const [draft, setDraft] = useState('');
  const p = sessionPrep(id);
  const pills = <ClinicianPills names={people} value={id} onChange={(v) => { setId(v); setPicked([]); setChooseOpen(false); }} />;
  if (!p) return { title: 'Session prep', toolbar: { trailing: PREP_TOOLBAR }, inset: 16, pinned: pills, body: null };

  const notesText = notes[id] ?? p.prepNotes;
  const bringList = bring[id] ?? p.bring;
  const when = p.sinceIsLast ? 'since your last session' : 'lately';
  const addNote = (text: string) => setNotes((n) => ({ ...n, [id]: ((n[id] ?? p.prepNotes) ? `${n[id] ?? p.prepNotes}\n\n` : '') + text }));
  const setBringList = (next: { text: string; done: boolean }[]) => setBring((b) => ({ ...b, [id]: next }));
  const addBring = () => { const text = draft.trim(); if (text) { setBringList([...bringList, { text, done: false }]); setDraft(''); } };

  return {
    title: 'Session prep', toolbar: { trailing: PREP_TOOLBAR }, inset: 16, pinned: pills,
    body: (
      <div key={id} className="au-stack-16" style={{ width: '100%' }}>
        {p.about && (
          <Card><div className="au-stack-8"><SectionHeader icon="person.text.rectangle" title={`About ${p.name}`} /><div className="au-subheadline" style={{ textAlign: 'left' }}>{p.about}</div></div></Card>
        )}
        <Card>
          <div className="au-stack-8">
            <SectionHeader icon="calendar.badge.clock" title="Next session" />
            {p.next ? <div className="au-prep-date">{p.next}</div> : <div className="au-subheadline au-secondary" style={{ textAlign: 'left' }}>No session scheduled yet.</div>}
          </div>
        </Card>
        {p.recovery.length > 0 && (
          <PrepCard icon="calendar.badge.checkmark" tint="sage" title={`Recovery ${when}`} note={NOTE} onAdd={addNote}
            summary={() => `Recovery ${when}:\n` + p.recovery.map((r) => `${r.name}: ${r.lines.join(', ')}`).join('\n')}>
            <div className="au-stack-6">{p.recovery.map((r) => (
              <div key={r.name} className="au-stack-2"><span className="au-prep-sub">{r.name}</span>{r.lines.map((l) => <span key={l} className="au-prep-line">{l}</span>)}</div>
            ))}</div>
          </PrepCard>
        )}
        <PrepCard icon="book.fill" title={`Journal ${when}`} note={`${NOTE} Check-ins are only counted.`} onAdd={addNote}
          summary={() => `Journal ${when}: ${p.journalParts || 'nothing written'} since ${p.since}.` + p.journalEntries.filter((e) => picked.includes(e.id)).map((e) => `\n- ${e.day}: ${e.line}`).join('')}>
          <div className="au-stack-8">
            <span className="au-prep-line">{p.journalParts ? p.journalLine : `Nothing written since ${p.since}.`}</span>
            {p.journalEntries.length > 0 && (
              <>
                <button type="button" className="au-choose" onClick={() => setChooseOpen((o) => !o)}>Choose entries to bring<span className="au-secondary"><Glyph name={chooseOpen ? 'chevron.right' : 'chevron.down'} size={20} weight={2.4} /></span></button>
                {chooseOpen && (
                  <div className="au-choose-list">{p.journalEntries.map((e) => (
                    <button key={e.id} type="button" className="au-pick" onClick={() => setPicked((x) => (x.includes(e.id) ? x.filter((y) => y !== e.id) : [...x, e.id]))}>
                      <span className="au-ringicon"><Glyph name={picked.includes(e.id) ? 'checkmark.circle.fill' : 'circle'} size={24} weight={1.5} /></span>
                      <span className="au-stack-1"><span className="au-caption2 au-secondary">{e.day}{e.bookmarked ? ' \u00b7 bookmarked' : ''}</span><span className="au-subheadline">{e.line}</span></span>
                    </button>
                  ))}</div>
                )}
              </>
            )}
          </div>
        </PrepCard>
        {p.sleep.length > 1 && (
          <PrepCard icon="moon.zzz.fill" title={`Sleep ${when}`} note={NOTE} onAdd={addNote} summary={() => `Sleep ${when}:\n${p.sleep.join('\n')}`}>
            <div className="au-stack-2">{p.sleep.map((l) => <span key={l} className="au-prep-line">{l}</span>)}</div>
          </PrepCard>
        )}
        {p.raise.length > 0 && (
          <PrepCard icon="text.bubble.fill" title="Waiting to be raised" note={NOTE} onAdd={addNote} summary={() => 'To raise:\n' + p.raise.map((r) => `- ${r.text}`).join('\n')}>
            <div className="au-bullets">{p.raise.map((r) => <div key={r.text} className="au-bullet"><Glyph name={r.isQuestion ? 'questionmark.circle' : 'circle.fill'} size={r.isQuestion ? 16 : 12} weight={1.8} /><span>{r.text}</span></div>)}</div>
          </PrepCard>
        )}
        <Card>
          <div className="au-stack-10">
            <SectionHeader icon="list.bullet.rectangle" title="To bring" />
            {bringList.map((b, i) => (
              <div key={b.text + i} className="au-bring-row">
                <button type="button" className="au-pick" onClick={() => setBringList(bringList.map((x, j) => (j === i ? { ...x, done: !x.done } : x)))}>
                  <span className="au-ringicon" style={b.done ? { color: 'var(--anchor-sage)' } : undefined}><Glyph name={b.done ? 'checkmark.circle.fill' : 'circle'} size={26} weight={1.5} /></span>
                  <span className={b.done ? 'au-secondary' : undefined}>{b.text}</span>
                </button>
                <button type="button" className="au-xbtn" aria-label={`Remove ${b.text}`} onClick={() => setBringList(bringList.filter((_, j) => j !== i))}><Glyph name="xmark" size={18} weight={2} /></button>
              </div>
            ))}
            <div className="au-bring-add">
              <input placeholder="Add something to bring" value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && addBring()} />
              <button type="button" className={draft.trim() ? 'on' : ''} onClick={addBring}>Add</button>
            </div>
          </div>
        </Card>
        <Card>
          <div className="au-stack-10">
            <SectionHeader icon="list.bullet.clipboard.fill" title="Prep notes" />
            {notesText ? <div className="au-notes-text">{notesText.split('\n').map((l, i) => <div key={i} style={{ minHeight: l ? undefined : 10 }}>{l}</div>)}</div> : <div className="au-subheadline au-secondary" style={{ textAlign: 'left' }}>Nothing here yet. Add from the cards above, or write your own.</div>}
          </div>
        </Card>
        <div><SecondaryButton><Glyph name="doc.plaintext" size={18} weight={1.8} />Make a one-page sheet</SecondaryButton></div>
        <div style={{ height: 70 }} />
      </div>
    ),
  };
}

/** The "Post-session notes" list behind After session. */
export function useAfterSession(): DetailParts {
  const people = clinicians();
  const [id, setId] = useState(people[0]?.id ?? '');
  const list = postSessions(id);
  return {
    title: 'Post-session notes', toolbar: { trailing: PREP_TOOLBAR }, inset: 16,
    pinned: <ClinicianPills names={people} value={id} onChange={setId} />,
    body: (
      <>
        {list.length === 0 && <div className="au-subheadline au-secondary" style={{ textAlign: 'left' }}>No past sessions yet.</div>}
        {list.map((s) => (
          <Card key={s.when}>
            <div className="au-listcard">
              <div className="au-listcard-main" style={{ gap: 2 }}><span className="au-headline">{s.when}</span><span className="au-caption au-secondary">{s.note}</span></div>
              <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
            </div>
          </Card>
        ))}
      </>
    ),
  };
}

/** The Bridge draft list behind Things to raise. */
export function useBridgeDraft(): DetailParts {
  const [toggled, setToggled] = useState<string[]>([]);
  const rows = bridgeDraftRows();
  return {
    title: 'Bridge draft', toolbar: { trailing: ['questionmark.circle', 'line.3.horizontal.decrease.circle', 'square.and.arrow.up', 'plus'] }, inset: 18,
    body: <>{rows.map((r) => {
      const resolved = r.resolved !== toggled.includes(r.text);
      return (
        <Card key={r.text}>
          <div className="au-taskcard-top">
            <button type="button" className="au-ring" aria-label={`Mark ${r.text} as ${resolved ? 'open' : 'resolved'}`} onClick={() => setToggled((t) => (t.includes(r.text) ? t.filter((x) => x !== r.text) : [...t, r.text]))} style={resolved ? { color: 'var(--anchor-sage)' } : undefined}>
              <Glyph name={resolved ? 'checkmark.circle.fill' : 'circle'} size={26} weight={1.5} />
            </button>
            <div className="au-taskcard-text">
              {r.isQuestion && <span className="au-fact"><Glyph name="questionmark.circle" size={17} weight={1.8} />Question</span>}
              <span className={`au-body${resolved ? ' au-secondary' : ''}`}>{r.text}</span>
              {resolved && r.answer && <span className="au-subheadline au-secondary">Answer: {r.answer}</span>}
              <span className="au-caption au-tertiary">{r.meta}</span>
            </div>
          </div>
        </Card>
      );
    })}</>,
  };
}
