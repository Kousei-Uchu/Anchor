import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { Icon } from './Icons';

/* A tappable rebuild of the real app's main screens, with made-up content.
   Used full-size on /demo and the home page, and (non-interactive, driven by props) in the scroll story. */

const SCRIPTS = [
  'I need 10 minutes, then we can talk.',
  "I'm not okay right now. I need space, not a conversation.",
  "Can we pause this? I'll come find you when I've calmed down.",
];
const AFFIRMATIONS = [
  'I got through today. That counts.',
  'Small steps still move me forward.',
  "I don't have to figure it all out tonight.",
];
const TOOLS: Record<string, string[]> = {
  '5-4-3-2-1': [
    'Name 5 things you can see.',
    'Name 4 things you can touch.',
    'Name 3 things you can hear.',
    'Name 2 things you can smell.',
    'Take 1 slow breath.',
  ],
  'Cold water': ['Go to a tap.', 'Run cold water over your wrists.', 'Breathe out slowly, twice.'],
};
const PROMPTS = [
  "What's currently on your mind?",
  "What's your biggest emotion right now?",
  "What's something you're looking forward to?",
];
const SLIDERS = ['Physical energy', 'Mental clarity', 'Room in your head', 'Physical energy to move', 'Social energy'];
const QUIET_LINE = 'No pressure to do anything right now.';

type Sheet =
  | { k: 'open'; title: string }
  | { k: 'new' }
  | { k: 'checkin'; stage: 's' | 'p'; i: number }
  | { k: 'tool'; name: string; i: number };

const TABS: { name: string; icon: string }[] = [
  { name: 'Now', icon: 'sun' },
  { name: 'Plan', icon: 'map' },
  { name: 'Journal', icon: 'pen' },
  { name: 'Bridge', icon: 'swap' },
  { name: 'Thread', icon: 'chat' },
];

function Mas() {
  return (
    <div className="mb">
      <svg aria-hidden="true">
        <use href="#anc" />
      </svg>
    </div>
  );
}

function SH({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <div className="sh">
      <i>
        <Icon name={icon} />
      </i>
      <span>{children}</span>
    </div>
  );
}

export function DemoApp({ tab, scrollTo, locked = false }: { tab?: number; scrollTo?: number; locked?: boolean }) {
  const root = useRef<HTMLDivElement>(null);
  const [own, setOwn] = useState(0);
  const cur = tab ?? own;

  const [items, setItems] = useState<string[]>(['Drink some water']);
  const [done, setDone] = useState<Set<number>>(new Set());
  const [newItem, setNewItem] = useState('');
  const [si, setSi] = useState(0);
  const [ai, setAi] = useState(0);
  const [entries, setEntries] = useState([{ t: 'Slept badly, but the walk helped a bit.', h: 'Yesterday, 8:12 pm' }]);
  const [line, setLine] = useState("Hey. I'm here.");
  const [draft, setDraft] = useState('');

  const [open, setOpen] = useState(false);
  const [sheet, setSheet] = useState<Sheet>({ k: 'open', title: '' });
  const [call, setCall] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const toastTimer = useRef<number | undefined>(undefined);

  useEffect(() => () => window.clearTimeout(toastTimer.current), []);

  useEffect(() => {
    const pane = root.current?.querySelector<HTMLElement>('.pane.on');
    const calm = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    pane?.scrollTo({ top: scrollTo ?? 0, behavior: calm ? 'auto' : 'smooth' });
  }, [cur, scrollTo]);

  const show = (s: Sheet) => {
    setSheet(s);
    setOpen(true);
  };
  const close = () => {
    setOpen(false);
    setCall(null);
  };
  const say = (m: string) => {
    close();
    setToast(m);
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), 2400);
  };
  const finishCheckIn = () => {
    setLine(QUIET_LINE);
    close();
  };
  const goTab = (i: number) => {
    setOwn(i);
    close();
  };

  const header = (title: string) => (
    <>
      <div className="row2" style={{ marginBottom: 10 }}>
        <button type="button" className="btn sec" onClick={close}>Cancel</button>
        <div className="sp" />
      </div>
      <h3>{title}</h3>
    </>
  );

  const tile = (icon: string, title: string, sg = false) => (
    <button type="button" key={title} className={`tile${sg ? ' sg' : ''}`} onClick={() => show({ k: 'open', title })}>
      <i><Icon name={icon} /></i>
      <span>{title}</span>
    </button>
  );
  const trow = (title: string, tiles: ReactNode) => (
    <div className="tr">
      <h4>{title}</h4>
      <div className="tl">{tiles}</div>
    </div>
  );

  /* ---------- panes ---------- */
  const now = (
    <>
      <div className="nt">
        Now
        <button type="button" className="ib" aria-label="Settings" onClick={() => show({ k: 'open', title: 'Settings' })}>
          <Icon name="cog" />
        </button>
      </div>
      <div className="pad stack">
        <div className="crisis">
          <b><Icon name="shield" /> Crisis numbers</b>
          <div className="row"><span>Emergency</span><span>000</span></div>
          <div className="row"><span>Lifeline (call)</span><span>13 11 14</span></div>
          <div className="row"><span>Lifeline (text)</span><span>0477 13 11 14</span></div>
          <div className="rg">Numbers for Australia. Change</div>
        </div>
        <div className="mas"><Mas /><div className="bub">{line}</div></div>
        <button type="button" className="btn" onClick={() => show({ k: 'checkin', stage: 's', i: 0 })}>
          <Icon name="grid" /> Check in
        </button>
        <div className="card">
          <SH icon="msg">Quick contact</SH>
          <div className="row2">
            <div className="sp"><b>Sam</b><div className="sub">Trusted</div></div>
            <button type="button" className="btn sec" onClick={() => setCall('Sam')}>Call</button>
            <button type="button" className="btn sec" onClick={() => say('Messages would open with a message ready to review.')}>Message</button>
          </div>
        </div>
        <div className="card">
          <SH icon="cal">Next appointment</SH>
          <b>Dr Lee</b>
          <div className="sub">Tuesday, 10:30 am</div>
        </div>
        <button type="button" className="btn sec block" onClick={() => show({ k: 'open', title: 'Safety plan' })}>Open my safety plan</button>
        <div className="card">
          <SH icon="lst">Decision presets</SH>
          <div className="sub" style={{ marginBottom: 10 }}>One less thing to decide right now. Tap a category&rsquo;s top pick, or see all your options.</div>
          <button type="button" className="btn sec" onClick={() => say('Outfit: grey hoodie')}>Outfit</button>{' '}
          <button type="button" className="btn sec" onClick={() => say('Food: toast')}>Food</button>{' '}
          <button type="button" className="btn sec" onClick={() => say('Morning routine: shower first')}>Morning routine</button>
        </div>
        <div className="card sg">
          <SH icon="leaf">Grounding tools</SH>
          {Object.keys(TOOLS).map((k) => (
            <button type="button" key={k} className="btn sec g" style={{ margin: '0 8px 8px 0' }} onClick={() => show({ k: 'tool', name: k, i: 0 })}>{k}</button>
          ))}
        </div>
        <div className="card">
          <SH icon="hg">Next hour only</SH>
          {items.length ? (
            items.map((t, i) => (
              <div className="row2" style={{ marginBottom: 10 }} key={i}>
                <button
                  type="button"
                  className={`chk${done.has(i) ? ' on' : ''}`}
                  aria-pressed={done.has(i)}
                  aria-label={`Mark "${t}" done`}
                  onClick={() => setDone((d) => { const n = new Set(d); if (n.has(i)) n.delete(i); else n.add(i); return n; })}
                >
                  {done.has(i) ? '✓' : ''}
                </button>
                <span className="sp">{t}</span>
              </div>
            ))
          ) : (
            <div className="sub">Nothing added yet.</div>
          )}
          <input
            className="in"
            placeholder="Add something small"
            value={newItem}
            onChange={(e) => setNewItem(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && newItem.trim()) {
                setItems((it) => [...it, newItem.trim()]);
                setNewItem('');
              }
            }}
          />
        </div>
        <div className="card sg">
          <SH icon="wind">De-escalation script</SH>
          <div className="quote">{'“'}{SCRIPTS[si]}{'”'}</div>
          <button type="button" className="btn sec g" onClick={() => setSi((si + 1) % SCRIPTS.length)}>Try another</button>
        </div>
        <div className="card">
          <SH icon="spk">Something to hold onto</SH>
          <div className="quote">{AFFIRMATIONS[ai]}</div>
          <button type="button" className="btn sec" onClick={() => setAi((ai + 1) % AFFIRMATIONS.length)}>Another</button>
        </div>
      </div>
    </>
  );

  const plan = (
    <>
      <div className="nt">Plan</div>
      {trow('Safety & people', <>{tile('ppl', 'Contacts')}{tile('shield', 'Safety plan')}{tile('clk', 'Trigger windows', true)}{tile('cal', 'Appointments', true)}</>)}
      {trow('Presets & tools', <>{tile('leaf', 'Grounding tools', true)}{tile('lst', 'Decision presets')}{tile('wind', 'De-escalation', true)}{tile('spk', 'Affirmations')}</>)}
      {trow('Data', tile('drv', 'Your data'))}
      <div className="pad" style={{ marginTop: 20 }}>
        <div className="card sg">
          <SH icon="cog">Preferences</SH>
          <div className="row2">
            <span className="sp">Lock with Face ID</span>
            <span className="chk on" style={{ background: 'var(--S)', borderColor: 'var(--S)' }}>{'✓'}</span>
          </div>
        </div>
      </div>
    </>
  );

  const journal = (
    <>
      <div className="nt">
        Journal
        <button type="button" className="ib" aria-label="New entry" onClick={() => { setDraft(''); show({ k: 'new' }); }}>
          <Icon name="plus" />
        </button>
      </div>
      <div className="srch"><Icon name="sch" /> Search your journal</div>
      <div className="pad">
        <div className="day">Today</div>
        {entries.map((e, i) => (
          <div className="ent" key={i}>
            <div className="cap">{e.h}</div>
            <div className="card">{e.t}</div>
          </div>
        ))}
      </div>
    </>
  );

  const bridge = (
    <>
      <div className="nt">Bridge</div>
      {trow('For your psych', <>{tile('doc', 'Draft notes')}{tile('clip', 'Session prep')}{tile('note', 'Post-session notes')}</>)}
      {trow('Tools & reference', <>{tile('loop', 'Reframing', true)}{tile('net', 'Feedback loops', true)}</>)}
    </>
  );

  const thread = (
    <>
      <div className="nt">Thread</div>
      {trow('With someone', <>{tile('chat', 'Message log')}{tile('cal', 'Support calendar')}</>)}
      <div className="note">Message log is tied to a real contact and can actually send.</div>
      {trow('Just for you', <>{tile('ml', 'To future me', true)}{tile('sq', "Things I haven't said", true)}</>)}
      <div className="note">&ldquo;Things I haven&rsquo;t said&rdquo; is for big things you might never send, to anyone.</div>
    </>
  );
  const panes = [now, plan, journal, bridge, thread];

  /* ---------- sheet bodies ---------- */
  let body: ReactNode = null;
  if (sheet.k === 'open') {
    body = (
      <>
        {header(sheet.title)}
        <div className="card" style={{ marginTop: 14 }}>
          This opens <b>{sheet.title}</b> in the full app. This demo covers the main screens.
        </div>
      </>
    );
  } else if (sheet.k === 'new') {
    body = (
      <>
        {header("New entry")}
        <textarea className="in" rows={8} placeholder={'Write something…'} style={{ marginTop: 12 }} value={draft} onChange={(e) => setDraft(e.target.value)} />
        <div style={{ marginTop: 14 }}>
          <button
            type="button"
            className="btn"
            onClick={() => {
              if (draft.trim()) setEntries((es) => [{ t: draft.trim(), h: 'Just now' }, ...es]);
              close();
            }}
          >
            Save
          </button>
        </div>
      </>
    );
  } else if (sheet.k === 'checkin' && sheet.stage === 'p') {
    const last = sheet.i >= PROMPTS.length - 1;
    body = (
      <>
        {header("Check in")}
        <div className="sub" style={{ textAlign: 'center' }}>Question {sheet.i + 1} of {PROMPTS.length}, skip any of these</div>
        <div style={{ fontSize: 20, margin: '24px 0', textAlign: 'center' }}>{PROMPTS[sheet.i]}</div>
        <input className="in" placeholder="Optional" />
        <div style={{ marginTop: 20 }}>
          <button type="button" className="btn" onClick={() => (last ? finishCheckIn() : show({ k: 'checkin', stage: 'p', i: sheet.i + 1 }))}>
            {last ? 'Finish' : 'Next'}
          </button>
        </div>
        <div style={{ marginTop: 10, textAlign: 'center' }}>
          <button type="button" className="btn sec" onClick={finishCheckIn}>Finish now, skip the rest</button>
        </div>
      </>
    );
  } else if (sheet.k === 'checkin') {
    body = (
      <>
        {header("Check in")}
        <div className="mas" style={{ margin: '14px 0' }}><Mas /><div className="bub">Want to check in? Totally fine to skip.</div></div>
        <div className="card">
          {SLIDERS.map((l) => (
            <div className="sl" key={l}>{l}<input type="range" min={0} max={100} defaultValue={50} aria-label={l} /></div>
          ))}
          <div className="cap">More = better, across all five. Just for you, nothing here is scored, averaged, or shown as a streak.</div>
        </div>
        <div style={{ marginTop: 16 }}><button type="button" className="btn" onClick={finishCheckIn}>Finish</button></div>
        <div style={{ marginTop: 10, textAlign: 'center' }}>
          <button type="button" className="btn sec" onClick={() => show({ k: 'checkin', stage: 'p', i: 0 })}>A few optional questions</button>
        </div>
        <div className="cap" style={{ textAlign: 'center', marginTop: 8 }}>Finishing here is complete. The questions are extra, not required.</div>
      </>
    );
  } else if (sheet.k === 'tool') {
    const steps = TOOLS[sheet.name];
    const last = sheet.i >= steps.length - 1;
    body = (
      <>
        {header(sheet.name)}
        <div className="cap" style={{ textAlign: 'center' }}>Step {sheet.i + 1} of {steps.length}</div>
        <div style={{ fontSize: 22, margin: '30px 0', textAlign: 'center' }}>{steps[sheet.i]}</div>
        <div className="row2">
          <button type="button" className="btn sec" onClick={() => show({ k: 'tool', name: sheet.name, i: Math.max(0, sheet.i - 1) })}>Back</button>
          <div className="sp" />
          <button type="button" className="btn" style={{ width: 'auto', padding: '11px 30px' }} onClick={() => (last ? close() : show({ k: 'tool', name: sheet.name, i: sheet.i + 1 }))}>
            {last ? 'Close' : 'Next'}
          </button>
        </div>
      </>
    );
  }

  return (
    <div className="app" ref={root}>
      <div className="sb"><span>9:41</span><span>{'●●●'}</span></div>
      <div className="isl" />
      {panes.map((p, i) => (
        <div className={`pane${i === cur ? ' on' : ''}`} key={i}>{p}</div>
      ))}
      <div className="tab">
        {TABS.map((t, i) => (
          <button type="button" key={t.name} className={i === cur ? 'on' : ''} onClick={() => goTab(i)} aria-current={i === cur ? 'page' : undefined}>
            <Icon name={t.icon} />
            {t.name}
          </button>
        ))}
      </div>
      <div className={`ov${open || call ? ' on' : ''}`} onClick={close} />
      <div className={`sheet${open ? ' on' : ''}`} role="dialog" inert={!open}>{body}</div>
      <div className={`alert${call ? ' on' : ''}`} role="alertdialog" inert={!call}>
        <b>Call {call}?</b>
        <div className="sub" style={{ margin: '6px 0 16px' }}>This is the confirmation screen the widget opens.</div>
        <button type="button" className="btn" onClick={() => say('Calling (demo only)')}>Call</button>
        <div style={{ marginTop: 8 }}><button type="button" className="btn sec" onClick={close}>Cancel</button></div>
      </div>
      <div className={`toast${toast ? ' on' : ''}`} role="status">{toast}</div>
      <div className="hi" />
      <div className={`lockov${locked ? ' on' : ''}`}>
        <span className="lockic"><Icon name="lock" /></span>
        <b>Anchor is locked</b>
        <span className="sub">Unlock with Face ID</span>
      </div>
    </div>
  );
}
