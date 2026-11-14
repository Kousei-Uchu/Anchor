// Reads demo.seed.generated.json, which scripts/sync-seed.mjs builds from the app's own demo data (DemoMode in AnchorApp.swift).
// Dates in that file are Swift expressions such as ago(12) or a Calendar lookup. The functions here work out the same dates on the website.
import raw from './demo.seed.generated.json';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Row = Record<string, any>;
const models = raw.models as unknown as Record<string, Row[]>;
const bindings = raw.bindings as unknown as Record<string, { $expr?: string } | string>;

export const rows = (type: string): Row[] => models[type] ?? [];
export const enumOf = (v: unknown): string => (v && typeof v === 'object' && '$enum' in (v as object) ? String((v as Row).$enum) : String(v ?? ''));
export const idOf = (v: unknown): string | null => (v && typeof v === 'object' && '$id' in (v as object) ? String((v as Row).$id) : null);

const DAY = 86_400_000;
/** The demo's "now": today at 10:25 am, the time of day the app's demo data is built around, so every visitor sees the same day grouping. */
export const demoNow = () => { const d = new Date(); d.setHours(10, 25, 0, 0); return d; };
export const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

/** Works out a date the way the Swift seed writes it: ago(days, hour), day(n), at(n, hour), now.addingTimeInterval(n * 86_400), or the `tuesday` Calendar lookup. */
export function resolveDate(v: unknown, now: Date = demoNow()): Date | null {
  if (!v || typeof v !== 'object') return null;
  const o = v as Row;
  const hourArg = (a: unknown) => (typeof a === 'number' ? a : typeof a === 'object' && a ? Number((a as Row).hour ?? 0) : 0);
  if (o.$call === 'ago') return new Date(now.getTime() - Number(o.args[0]) * DAY - hourArg(o.args[1]) * 3_600_000);
  if (o.$call === 'day') return startOfDay(new Date(now.getTime() - Number(o.args[0]) * DAY));
  if (o.$call === 'at') return new Date(startOfDay(new Date(now.getTime() - Number(o.args[0]) * DAY)).getTime() + hourArg(o.args[1]) * 3_600_000);
  const bound = o.$ref ? bindings[o.$ref] : undefined;
  const expr: string | undefined = o.$expr ?? (typeof bound === 'object' ? bound?.$expr : undefined);
  if (!expr) return null;
  const add = /now\.addingTimeInterval\((-?\d+) \* 86_400\)/.exec(expr);
  const cal = /DateComponents\(hour: (\d+), minute: (\d+), weekday: (\d+)\)/.exec(expr);
  if (cal) {
    const [h, m, wd] = [Number(cal[1]), Number(cal[2]), Number(cal[3]) - 1];
    for (let i = 0; i < 8; i++) {
      const c = startOfDay(new Date(now.getTime() + i * DAY)); c.setHours(h, m, 0, 0);
      if (c > now && c.getDay() === wd) return c;
    }
  }
  if (add) return new Date(now.getTime() + Number(add[1]) * DAY);
  return null;
}

/** "10 Nov 2026 at 10:30 am", like Swift's formatted(date: .abbreviated, time: .shortened) in an Australian locale. */
export function formatAppointment(d: Date): string {
  const date = new Intl.DateTimeFormat('en-AU', { day: 'numeric', month: 'short', year: 'numeric' }).format(d);
  const time = new Intl.DateTimeFormat('en-AU', { hour: 'numeric', minute: '2-digit', hour12: true }).format(d).toLowerCase().replace(/\s/g, ' ');
  return `${date} at ${time}`;
}

export function daysUntilLabel(d: Date, now: Date = demoNow()): string {
  const days = Math.round((startOfDay(d).getTime() - startOfDay(now).getTime()) / DAY);
  if (days <= 0) return 'Today';
  if (days === 1) return 'Tomorrow';
  return `In ${days} days`;
}

/** NextAppointmentCardView: the earliest future occurrence across all series. */
export function nextAppointment(now: Date = demoNow()) {
  let best: { name: string; date: Date } | null = null;
  for (const s of rows('AppointmentSeries')) {
    for (const o of s.occurrences ?? []) {
      const date = resolveDate(o.scheduledDate, now);
      if (date && date > now && (!best || date < best.date)) best = { name: s.clinicianLabel, date };
    }
  }
  return best;
}

const EARLY = [1, 3, 7, 14, 21, 30, 60, 90, 120, 180, 270, 365];
const daysText = (n: number) => `${n} ${n === 1 ? 'day' : 'days'}`;
const milestoneLabel = (n: number) => (n >= 365 && n % 365 === 0 ? `${n / 365} ${n / 365 === 1 ? 'year' : 'years'}` : daysText(n));

/** RecoveryNowCard: the counters, with the big number and the line under the name. */
export function recoveryCounters(now: Date = demoNow()) {
  return rows('RecoveryCounter').filter((c) => !c.isArchived).map((c) => {
    const run = (c.runs ?? []).find((r: Row) => r.end === null || r.end === undefined);
    const start = run ? resolveDate(run.start, now) : null;
    const days = start ? Math.max(0, Math.floor((now.getTime() - start.getTime()) / DAY)) : 0;
    const acknowledged: number[] = c.acknowledgedMilestones ?? [];
    const reached = EARLY.filter((m) => m <= days).find((m) => !acknowledged.includes(m));
    const next = EARLY.find((m) => m > days) ?? (Math.floor(days / 365) + 1) * 365;
    return { name: String(c.name), number: String(days), label: days === 1 ? 'day' : 'days', line: reached ? `You've reached ${milestoneLabel(reached)}.` : `Next: ${milestoneLabel(next)}` };
  });
}

/** TasksNowCard: top-level, not done, not set aside, not waiting on another task, ordered by when it is due and then by sort order. */
export function openTasks(): { id: string; title: string }[] {
  const all = rows('TaskItem');
  const open = (id: string | null) => !!id && all.some((t) => t._id === id && !t.isDone);
  const bucket = (t: Row) => {
    const due = (t._calls ?? []).find((c: Row) => c.name === 'setDue');
    const kind = enumOf(due?.args?.[0] ?? t.dueKind);
    return kind === 'today' || kind === 'asap' ? 0 : kind === 'thisWeek' ? 1 : kind === 'thisMonth' || kind === 'exact' ? 2 : 3;
  };
  return all
    .filter((t) => !t.parentID && !t.isDone && enumOf(t.status) !== 'setAside' && !(t.blockedByIDs ?? []).some((b: unknown) => open(idOf(b))))
    .sort((a, b) => bucket(a) - bucket(b) || Number(a.sortOrder ?? 0) - Number(b.sortOrder ?? 0))
    .map((t) => ({ id: String(t._id ?? t.title), title: String(t.title) }));
}

/** DecisionPresetsQuickView: each category's first choice, and the routines that have steps. */
export function decisionPresets() {
  const cats = [...rows('DecisionPresetCategory')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder));
  const choices = rows('DecisionPresetChoice');
  const picks = cats.flatMap((c) => {
    const first = choices.filter((x) => idOf(x.category) === c._id).sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder))[0];
    return first ? [{ category: String(c.name), name: String(first.name) }] : [];
  });
  const routines = rows('Routine').filter((r) => (r.steps ?? []).length > 0).sort((a, b) => (resolveDate(a.createdAt)?.getTime() ?? 0) - (resolveDate(b.createdAt)?.getTime() ?? 0)).map((r) => String(r.name));
  return { picks, routines };
}

export const quickContacts = () => [...rows('TrustedContact')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).slice(0, 2).map((c) => String(c.name));
export const messageStarters = () => [...rows('MessageStarter')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((m) => String(m.text)).filter((t) => t.trim());
export const groundingTools = () => [...rows('GroundingTool')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((t) => String(t.title));
export const affirmations = () => [...rows('Affirmation')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((a) => String(a.text));
export const deEscalationScripts = () => [...rows('DeEscalationScript')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((a) => String(a.text));

/** SafetyPlanWidget: the first line of the first two sections that have text. */
export function safetyGlance(): { title: string; line: string }[] {
  return [...rows('SafetyPlanSection')]
    .filter((s) => !s.isHidden)
    .sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder))
    .flatMap((s) => {
      const line = String(s.text ?? '').split('\n').map((l) => l.trim()).find(Boolean);
      return line ? [{ title: String(s.title || 'Untitled'), line }] : [];
    })
    .slice(0, 2);
}

const weekdayTime = (d: Date) => {
  const day = new Intl.DateTimeFormat('en-AU', { weekday: 'short' }).format(d);
  const time = new Intl.DateTimeFormat('en-AU', { hour: 'numeric', minute: '2-digit', hour12: true }).format(d).toLowerCase();
  return `${day} ${time}`;
};
export const formatWeekdayTime = weekdayTime;

/** TriggerWindowsWidget: the soonest start among windows that are switched on. */
export function soonestTriggerWindow(now: Date = demoNow()): { label: string; when: string } | null {
  let best: { label: string; date: Date } | null = null;
  for (const w of rows('TriggerWindow')) {
    if (w.isActive === false) continue;
    const days: number[] = w.daysOfWeek ?? [];
    for (let i = 0; i < 8; i++) {
      const c = startOfDay(new Date(now.getTime() + i * DAY));
      c.setHours(Number(w.startTime?.hour ?? 0), Number(w.startTime?.minute ?? 0), 0, 0);
      if (c > now && days.includes(c.getDay() + 1)) { if (!best || c < best.date) best = { label: String(w.label ?? ''), date: c }; break; }
    }
  }
  return best ? { label: best.label, when: weekdayTime(best.date) } : null;
}

/** AppointmentsWidget: the same next appointment as the Now card, written as "Tue 10:30 am". */
export function appointmentWidget(now: Date = demoNow()) {
  const next = nextAppointment(now);
  return next ? { when: weekdayTime(next.date), caption: `${next.name} \u00b7 ${daysUntilLabel(next.date, now)}` } : null;
}

/** MotivationsWidget */
export function motivationsSummary() {
  const list = [...rows('RecoveryMotivation')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder));
  return list.length ? { count: list.length, first: String(list[0].text) } : null;
}

/** RecoveryWidget: "Day 12" and the counter's name. */
export function recoveryWidget(now: Date = demoNow()) {
  const c = recoveryCounters(now)[0];
  return c ? { big: Number(c.number) >= 1 ? `Day ${c.number}` : 'Just started', name: c.name } : null;
}

/** TasksWidget */
export const tasksSummary = () => { const o = openTasks(); return o.length ? { count: o.length, first: o[0].title } : null; };

/** The text of a journal entry. A few demo entries are built from a variable, such as `optimisedOriginal + "\n" + ...`. */
function entryText(e: Row): string {
  if (typeof e.text === 'string') return e.text;
  const name = /^(\w+) \+/.exec(String(e.text?.$expr ?? ''))?.[1];
  const value = name ? bindings[name] : undefined;
  return typeof value === 'string' ? value : '';
}

/** JournalBlocks.previewLine: the first line with words, without leading # > * - marks. */
export function previewLine(text: string): string | null {
  for (const line of text.split('\n')) {
    const t = line.replace(/^[#>*\-\s]+/, '').trim();
    if (t) return t;
  }
  return null;
}

export type JournalItem =
  | { kind: 'entry'; time: Date; preview: string | null; bookmarked: boolean; chips: string[] }
  | { kind: 'checkin'; time: Date; answered: boolean; readings: { short: string; value: number }[] };

/** RecoveryJournalTag.chips: "Energy drinks \u00b7 11 days" for the run a date falls in. */
function recoveryChips(date: Date, now: Date): string[] {
  const out: string[] = [];
  for (const c of rows('RecoveryCounter')) {
    if (c.isArchived) continue;
    for (const run of c.runs ?? []) {
      const start = resolveDate(run.start, now);
      const end = run.end ? resolveDate(run.end, now) : null;
      if (start && date >= start && (!end || date < end)) {
        const n = Math.floor((date.getTime() - start.getTime()) / DAY);
        out.push(`${c.name} \u00b7 ${n} ${n === 1 ? 'day' : 'days'}`);
      }
    }
  }
  return out.slice(0, 2);
}

/** JournalView: entries and check-ins, newest first, grouped by day. */
export function journalDays(now: Date = demoNow()): { day: Date; items: JournalItem[] }[] {
  const clamp = (v: unknown) => Math.min(Math.max(Number(v ?? 0), 0), 1);
  const items: JournalItem[] = [];
  for (const e of rows('JournalEntry')) {
    const time = resolveDate(e.createdAt, now);
    if (time) items.push({ kind: 'entry', time, preview: previewLine(entryText(e)), bookmarked: !!e.isFavorited, chips: recoveryChips(time, now) });
  }
  for (const c of rows('CheckIn')) {
    const time = resolveDate(c.timestamp, now);
    if (!time) continue;
    items.push({
      kind: 'checkin', time, answered: !!c.extraAnswers,
      readings: [
        { short: 'Energy', value: clamp(1 - Number(c.physicalExhaustion)) }, { short: 'Clarity', value: clamp(1 - Number(c.cognitiveBurnout)) },
        { short: 'Room', value: clamp(1 - Number(c.mentalLoad)) }, { short: 'Moving', value: clamp(c.physicalEnergy) }, { short: 'Social', value: clamp(c.socialEnergy) },
      ],
    });
  }
  items.sort((a, b) => b.time.getTime() - a.time.getTime());
  const groups = new Map<number, JournalItem[]>();
  for (const it of items) { const k = startOfDay(it.time).getTime(); groups.set(k, [...(groups.get(k) ?? []), it]); }
  return [...groups.entries()].sort((a, b) => b[0] - a[0]).map(([k, list]) => ({ day: new Date(k), items: list }));
}

export const formatClock = (d: Date) => new Intl.DateTimeFormat('en-AU', { hour: 'numeric', minute: '2-digit', hour12: true }).format(d).toLowerCase();
