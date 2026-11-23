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
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
/** "3 Nov 2026", with the month abbreviations the app uses. */
export const shortDate = (d: Date) => `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
export const monthShort = (d: Date) => MONTHS[d.getMonth()];
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
  const date = shortDate(d);
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


/** RecoveryNowCard: the counters, with the big number and the line under the name. */
export function recoveryCounters(now: Date = demoNow()) {
  return rows('RecoveryCounter').filter((c) => !c.isArchived).map((c) => {
    const run = (c.runs ?? []).find((r: Row) => r.end === null || r.end === undefined);
    const start = run ? resolveDate(run.start, now) : null;
    const days = start ? Math.max(0, Math.floor((now.getTime() - start.getTime()) / DAY)) : 0;
    return { name: String(c.name), number: String(days), label: days === 1 ? 'day' : 'days', line: '' };  // milestones are off until switched on in Settings, so the row shows no milestone line
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

/** The app sorts by creation time, newest first. The demo rows without a creation date were all made together, so the one inserted last counts as newest. */
function newestFirst(list: Row[], field: string, now: Date): Row[] {
  const base = now.getTime();
  return list.map((r, i) => ({ r, t: resolveDate(r[field], now)?.getTime() ?? base + i * 1000 })).sort((a, b) => b.t - a.t).map((x) => x.r);
}

/** ThingsToRaiseWidget: the open items, newest first. */
export function thingsToRaise(now: Date = demoNow()): { id: string; text: string }[] {
  return newestFirst(rows('BridgeDraftItem'), 'createdAt', now).filter((i) => !i.isResolved).map((i) => ({ id: String(i._id ?? i.text), text: String(i.text) }));
}

/** NextSessionWidget caption */
export function nextSessionCaption(now: Date = demoNow()): string {
  const next = nextAppointment(now);
  return next ? `${next.name} \u00b7 ${formatAppointment(next.date)}` : 'No session scheduled. You can still prep.';
}

/** FeedbackLoopsWidget */
export function feedbackLoopsSummary(now: Date = demoNow()) {
  const list = newestFirst(rows('FeedbackLoopDiagram'), 'lastEditedAt', now);
  return list.length ? { count: list.length, latest: String(list[0].title || 'Untitled') } : null;
}

/** PersonalGoalsWidget: goals that are still active and have a title. */
export function personalGoalsSummary() {
  const working = [...rows('PersonalGoal')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder))
    .filter((g) => (enumOf(g.status) === 'active' || g.status === undefined) && String(g.title ?? '').trim());
  return working.length ? { first: String(working[0].title), more: working.length - 1 } : null;
}

/** MessageLogWidget: the latest message. */
export function latestMessage(now: Date = demoNow()) {
  const list = rows('ThreadMessage').map((m) => ({ m, t: resolveDate(m.timestamp, now) })).filter((x) => x.t).sort((a, b) => b.t!.getTime() - a.t!.getTime());
  return list.length ? { when: formatAppointment(list[0].t!), text: String(list[0].m.text || 'Voice note') } : null;
}

/** SupportCalendarWidget: this week, Monday first, with a dot on days that have an entry. */
export function supportWeek(now: Date = demoNow()) {
  const NARROW = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];
  const start = startOfDay(now); start.setDate(start.getDate() - ((start.getDay() + 6) % 7));
  const entryDays = rows('SupportCalendarEntry').map((e) => resolveDate(e.date, now)).filter(Boolean).map((d) => startOfDay(d!).getTime());
  return NARROW.map((narrow, i) => {
    const d = new Date(start); d.setDate(start.getDate() + i);
    return { narrow, day: d.getDate(), today: d.getTime() === startOfDay(now).getTime(), hasEntry: entryDays.includes(d.getTime()) };
  });
}

/** FutureNotesWidget */
export function futureNotesSummary(now: Date = demoNow()): { big?: string; caption: string } {
  const notes = [...rows('FutureNote')].sort((a, b) => (resolveDate(a.unlockDate, now)?.getTime() ?? 0) - (resolveDate(b.unlockDate, now)?.getTime() ?? 0));
  const isLetter = (n: Row) => String(n.openWhen ?? '').trim() !== '';
  const dated = notes.filter((n) => !isLetter(n));
  const ready = dated.filter((n) => (resolveDate(n.unlockDate, now)?.getTime() ?? 0) <= now.getTime()).length;
  const upcoming = dated.find((n) => (resolveDate(n.unlockDate, now)?.getTime() ?? 0) > now.getTime());
  const letters = notes.length - dated.length;
  if (ready > 0) return { big: `${ready} ready`, caption: 'Tap to open' };
  if (upcoming) {
    const days = Math.max(1, Math.round((startOfDay(resolveDate(upcoming.unlockDate, now)!).getTime() - startOfDay(now).getTime()) / DAY));
    return { caption: `Next unlocks in ${days} ${days === 1 ? 'day' : 'days'}` };
  }
  if (letters > 0) return { caption: letters === 1 ? '1 letter to open when you choose.' : `${letters} letters to open when you choose.` };
  return { caption: 'Write something for a later day.' };
}

/** BoundariesWidget: the first visible section that has text. */
export function boundariesGlance() {
  for (const s of [...rows('BoundarySection')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder))) {
    if (s.isHidden) continue;
    const line = String(s.text ?? '').split('\n').map((l) => l.trim()).find(Boolean);
    if (line) return { title: String(s.title || 'Untitled'), line };
  }
  return null;
}

/** PeopleWidget caption */
export function peopleCaption(): string {
  const names = [...rows('TrustedContact')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((c) => String(c.name).trim()).filter(Boolean);
  if (names.length === 0) return 'Add people under Contacts in Plan. Each gets a page of their own.';
  if (names.length === 1) return names[0];
  if (names.length === 2) return `${names[0]} and ${names[1]}`;
  if (names.length === 3) return `${names[0]}, ${names[1]}, and ${names[2]}`;
  return `${names[0]}, ${names[1]} and ${names.length - 2} more`;
}

/** UnsentDraftsWidget */
export const unsentDraftCount = () => rows('UnsentDraft').filter((d) => !d.wasSent).length;

/** ContactsEditorView: every contact, with "On Now" on the ones that are quick contacts (the first two). */
export function contactRows(): { name: string; phone: string; onNow: boolean }[] {
  return [...rows('TrustedContact')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder))
    .map((c, i) => ({ name: String(c.name || 'Unnamed'), phone: String(c.phoneNumber ?? ''), onNow: i < 2 }));
}

/** GroundingToolsEditorView: each tool with whether it has steps and when it applies. */
export function groundingToolRows(): { title: string; kindLabel: string; when: string; hasSteps: boolean }[] {
  const label: Record<string, string> = { morning: 'Morning', afternoon: 'Afternoon', evening: 'Evening', lateNight: 'Late night' };
  return [...rows('GroundingTool')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((t) => {
    const windows: string[] = (t.relevantTimeWindows ?? []).map((w: unknown) => label[enumOf(w)] ?? enumOf(w));
    return {
      title: String(t.title || 'Untitled tool'),
      kindLabel: enumOf(t.kind) === 'deepLink' ? 'Opens a link' : 'Steps',
      when: windows.length ? windows.join(' \u00b7 ') : 'Any time of day',
      hasSteps: String(t.steps ?? '').trim() !== '',
    };
  });
}

const dateOnly = shortDate;
const contactName = (ref: unknown) => { const id = idOf(ref); return String(rows('TrustedContact').find((c) => c._id === id)?.name ?? ''); };
const firstLine = (text: unknown) => String(text ?? '').split('\n').map((l) => l.trim()).find(Boolean) ?? '';

/** PeopleScreen: each contact with the first line of their first note. */
export function peopleRows(): { name: string; summary: string }[] {
  const sections = [...rows('PersonSection')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder));
  return [...rows('TrustedContact')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((c) => ({
    name: String(c.name),
    summary: firstLine(sections.find((s) => idOf(s.contactID) === c._id && firstLine(s.text))?.text) || 'Nothing written yet',
  }));
}

/** FutureNotesView: dated notes (locked or ready) and the "open when" letters. */
export function futureNoteRows(now: Date = demoNow()) {
  const all = rows('FutureNote');
  const isLetter = (n: Row) => String(n.openWhen ?? '').trim() !== '';
  const written = `Written ${dateOnly(now)}`;
  const dated = all.filter((n) => !isLetter(n)).sort((a, b) => (resolveDate(a.unlockDate, now)?.getTime() ?? 0) - (resolveDate(b.unlockDate, now)?.getTime() ?? 0)).map((n) => {
    const unlock = resolveDate(n.unlockDate, now);
    const locked = !!unlock && unlock > now;
    return { title: locked ? `Locked until ${dateOnly(unlock!)}` : 'Ready to open', subtitle: written, locked };
  });
  const letters = all.filter(isLetter).map((n) => ({ title: `Open when ${String(n.openWhen).trim()}`, subtitle: written }));
  return { dated, letters };
}

/** PersonalGoalsView: goals still being worked on, and the ones reached. */
export function goalGroups() {
  const sorted = [...rows('PersonalGoal')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder));
  const card = (g: Row) => {
    const bits = [g.termRaw === 'short' ? 'Short term' : g.termRaw === 'long' ? 'Long term' : '', g.usesSMART ? 'SMART' : '', (g.notes ?? []).length ? `${g.notes.length} ${g.notes.length === 1 ? 'note' : 'notes'}` : ''].filter(Boolean);
    return { title: String(g.title), why: String(g.why ?? ''), meta: bits.join(' \u00b7 ') };
  };
  return { working: sorted.filter((g) => enumOf(g.status) === 'active' || g.status === undefined).map(card), reached: sorted.filter((g) => enumOf(g.status) === 'reached').map(card) };
}

/** FeedbackLoopDiagramView's list. Ties in edit time are arbitrary in the demo, so this follows what the app shows: the map first, then the loops as added. */
export function diagramRows(): { title: string; summary: string; loop: boolean }[] {
  const list = rows('FeedbackLoopDiagram').map((d) => ({ title: String(d.title || 'Untitled'), summary: String(d._summary ?? ''), loop: Array.isArray(d._steps) }));
  return [...list.filter((d) => d.summary.startsWith('Map')), ...list.filter((d) => !d.summary.startsWith('Map'))];
}

/** BoundariesView */
export function boundaryCards() {
  return [...rows('BoundarySection')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).filter((s) => !s.isHidden)
    .map((s) => ({ title: String(s.title || 'Untitled'), icon: String(s.iconName || 'doc.text.fill'), tint: (String(s.tintName) === 'sage' ? 'sage' : 'accent') as 'sage' | 'accent', text: String(s.text ?? ''), shareable: !!s.isShareable }));
}

/** SupportCalendarView */
export function calendarEntries(now: Date = demoNow()) {
  return rows('SupportCalendarEntry').map((e) => ({ date: resolveDate(e.date, now)!, note: String(e.note ?? ''), visible: (e.visibleToContactIDs ?? []).map(contactName).filter(Boolean) }))
    .filter((e) => e.date).sort((a, b) => a.date.getTime() - b.date.getTime())
    .map((e) => ({ when: dateOnly(e.date), note: e.note, visibleTo: e.visible.length ? `Visible to ${e.visible.join(', ')}` : '' }));
}

/** ThreadMessagesView */
export function messageLog(now: Date = demoNow()) {
  return rows('ThreadMessage').map((m) => ({ t: resolveDate(m.timestamp, now)!, who: contactName(m.withContactID), text: String(m.text ?? '') }))
    .filter((m) => m.t).sort((a, b) => b.t.getTime() - a.t.getTime())
    .map((m) => ({ who: m.who, text: m.text, when: formatAppointment(m.t) }));
}
export const writeToNames = (): string[] => [...rows('TrustedContact')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).map((c) => String(c.name));

/** SafetyPlanEditorView */
export function safetyPlan(now: Date = demoNow()) {
  const sections = [...rows('SafetyPlanSection')].sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder)).filter((s) => !s.isHidden)
    .map((s) => ({ title: String(s.title || 'Untitled'), icon: String(s.iconName || 'doc.text.fill'), tint: (String(s.tintName) === 'sage' ? 'sage' : 'accent') as 'sage' | 'accent', lines: String(s.text ?? '').split('\n').map((l) => l.trim()).filter(Boolean) }));
  return { sections, updated: `Last updated ${dateOnly(now)}` };
}

/** RecoveryHomeView: each counter with its totals and the next milestone. */
export function recoveryHome(now: Date = demoNow()) {
  return rows('RecoveryCounter').filter((c) => !c.isArchived).map((c) => {
    const runs: { start: Date; end: Date }[] = (c.runs ?? []).map((r: Row) => ({ start: resolveDate(r.start, now)!, end: (r.end ? resolveDate(r.end, now) : null) ?? now })).filter((r: { start: Date | null }) => r.start);
    const runDays = (r: { start: Date; end: Date }) => Math.max(0, Math.floor((r.end.getTime() - r.start.getTime()) / DAY));
    const current = (c.runs ?? []).findIndex((r: Row) => !r.end);
    const days = current >= 0 ? runDays(runs[current]) : 0;
    const total = runs.reduce((n, r) => n + runDays(r), 0);
    const summary = recoveryCounters(now).find((x) => x.name === c.name);
    return { name: String(c.name), days, total, showTotal: total !== days, number: String(days), label: days === 1 ? 'day' : 'days', next: summary?.line ?? '' };
  });
}

const TASK_BUCKETS = ['Today', 'This week', 'Later', 'No date', 'Waiting on something else', 'Set aside for now'];
const ENERGY_LABEL: Record<string, string> = { little: 'A little', some: 'Some', lots: 'A lot' };
const ENERGY_ICON: Record<string, string> = { little: 'battery.25percent', some: 'battery.50percent', lots: 'battery.100percent' };
const durationText = (m: number) => { const h = Math.floor(m / 60), r = m % 60; return h === 0 ? `${r} min` : r === 0 ? `${h} hr` : `${h} hr ${r} min`; };

export type TaskCardData = { id: string; title: string; done: boolean; waiting?: boolean; muted?: boolean; facts: { icon: string; text: string }[]; firstStep?: string; waitingOn?: string; steps: { title: string; done: boolean }[] };

/** TasksView: quick lists, then open tasks grouped by when they are due, then done tasks. */
export function taskScreen(now: Date = demoNow()) {
  const all = rows('TaskItem');
  const byId = (id: string | null) => all.find((t) => t._id === id);
  const top = all.filter((t) => !t.parentID);
  const stepsOf = (t: Row) => all.filter((s) => idOf(s.parentID) === t._id).sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder));
  const dueKind = (t: Row) => enumOf((t._calls ?? []).find((c: Row) => c.name === 'setDue')?.args?.[0] ?? t.dueKind);
  const openBlockers = (t: Row) => (t.blockedByIDs ?? []).map((b: unknown) => byId(idOf(b))).filter((b: Row | undefined) => b && !b.isDone) as Row[];
  const bucketOf = (t: Row) => {
    if (enumOf(t.status) === 'setAside') return 'Set aside for now';
    if (openBlockers(t).length) return 'Waiting on something else';
    const k = dueKind(t);
    return k === 'today' || k === 'asap' ? 'Today' : k === 'thisWeek' ? 'This week' : k === 'thisMonth' || k === 'exact' ? 'Later' : 'No date';
  };
  const dueText: Record<string, string> = { today: 'Today', thisWeek: 'This week', thisMonth: 'This month', asap: 'Soon' };
  const card = (t: Row): TaskCardData => {
    const steps = stepsOf(t);
    const doneSteps = steps.filter((s) => s.isDone).length;
    const started = !t.isDone && enumOf(t.status) !== 'setAside' && (enumOf(t.status) === 'inProgress' || doneSteps > 0);
    const blockers = openBlockers(t);
    const facts: { icon: string; text: string }[] = [];
    if (!t.isDone && dueText[dueKind(t)]) facts.push({ icon: 'calendar', text: dueText[dueKind(t)] });
    if (!t.isDone && Number(t.estimateMinutes) > 0) facts.push({ icon: 'clock', text: durationText(Number(t.estimateMinutes)) });
    if (started) facts.push({ icon: 'play.circle', text: 'Started' });
    const energy = enumOf(t.energy);
    if (!t.isDone && ENERGY_LABEL[energy]) facts.push({ icon: ENERGY_ICON[energy], text: ENERGY_LABEL[energy] });
    if (!t.isDone && steps.length) facts.push({ icon: 'checklist', text: `${doneSteps}/${steps.length}` });
    if (Number(t.focusSessions) > 0) facts.push({ icon: 'timer', text: Number(t.focusSessions) === 1 ? '1 session' : `${t.focusSessions} sessions` });
    const showsFirstStep = !t.isDone && !blockers.length && enumOf(t.status) !== 'setAside' && !started && String(t.firstStep ?? '').trim() !== '';
    return {
      id: String(t._id ?? t.title), title: String(t.title), done: !!t.isDone, waiting: blockers.length > 0, muted: blockers.length > 0 || enumOf(t.status) === 'setAside', facts,
      firstStep: showsFirstStep ? String(t.firstStep) : undefined,
      waitingOn: blockers.length ? (blockers.length === 1 ? `Waiting on ${blockers[0].title}` : `Waiting on ${blockers[0].title} and ${blockers.length - 1} more`) : undefined,
      steps: steps.map((s) => ({ title: String(s.title), done: !!s.isDone })),
    };
  };
  const open = top.filter((t) => !t.isDone).sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder));
  const buckets = TASK_BUCKETS.map((title) => ({ title, tasks: open.filter((t) => bucketOf(t) === title).map(card) })).filter((b) => b.tasks.length > 0);
  const done = top.filter((t) => t.isDone).map(card);
  const quickLists = rows('QuickList').filter((l) => !l.archivedAt).map((l) => ({ title: String(l.title), ticked: (l.items ?? []).filter((i: Row) => i.isDone).length, total: (l.items ?? []).length }));
  const archivedLists = rows('QuickList').filter((l) => l.archivedAt).length;
  return { quickLists, buckets, done, archivedLists };
}

// ---- Session prep, After session, Bridge draft, Things I haven't said, Journal month and year ----

const sortOrder = (a: Row, b: Row) => Number(a.sortOrder ?? 0) - Number(b.sortOrder ?? 0);
export const clinicians = (): { id: string; name: string }[] => [...rows('AppointmentSeries')].sort(sortOrder).map((s) => ({ id: String(s._id), name: String(s.clinicianLabel) }));
const asDay = shortDate;
const clockText = (h: number, m: number) => new Intl.DateTimeFormat('en-AU', { hour: 'numeric', minute: '2-digit', hour12: true }).format(new Date(2000, 0, 1, h, m)).toLowerCase();
const describeMinutes = (n: number) => { const h = Math.floor(n / 60), m = n % 60; return h === 0 ? `${m} min` : m === 0 ? `${h} h` : `${h} h ${m} min`; };

/** The demo's sleep nights, worked out the way DemoMode's loop does (the numbers and the loop's text are in demo.seed.generated.json). */
function sleepNights(now: Date) {
  return (raw.sleep.asleep as number[]).map((asleep, i) => {
    const night = startOfDay(new Date(now.getTime() - i * DAY));
    const wake = new Date(night.getTime() + 7 * 3_600_000 + (i % 3) * 900_000);
    const bed = new Date(wake.getTime() - (asleep + 20) * 60_000);
    return { night, bed, minutes: i === 3 ? asleep : Math.round((wake.getTime() - bed.getTime()) / 60_000) };
  });
}

/** SleepSessionSummaryCard.describingLines */
function sleepLines(since: Date, now: Date): string[] {
  const start = startOfDay(since);
  const nights = sleepNights(now).filter((n) => n.night >= start && n.night <= now);
  const lines = [`${nights.length === 1 ? '1 night' : `${nights.length} nights`} written down since ${asDay(since)}.`];
  const mins = nights.map((n) => n.minutes);
  if (mins.length) {
    const low = Math.min(...mins), high = Math.max(...mins);
    lines.push(mins.length === 1 ? `Asleep about ${describeMinutes(low)} on the night with a time.` : low === high ? `Asleep about ${describeMinutes(low)} each of those nights.` : `Time asleep from ${describeMinutes(low)} to ${describeMinutes(high)}.`);
  }
  const offsets = nights.map((n) => (n.bed.getHours() * 60 + n.bed.getMinutes() - 18 * 60 + 24 * 60) % (24 * 60)).sort((a, b) => a - b);
  if (offsets.length >= 3) {
    const round15 = (v: number) => Math.floor((v + 7) / 15) * 15;
    const low = round15(offsets[Math.round((offsets.length - 1) * 0.2)]), high = round15(offsets[Math.round((offsets.length - 1) * 0.8)]);
    const at = (o: number) => { const c = (o + 18 * 60) % (24 * 60); return clockText(Math.floor(c / 60), c % 60); };
    lines.push(low === high ? `Usually in bed around ${at(low)}.` : `Usually in bed between ${at(low)} and ${at(high)}.`);
  }
  return lines;
}

/** RecoverySummary.lines */
function recoveryLines(counter: Row, since: Date, now: Date): string[] {
  const rec = recoveryHome(now).find((r) => r.name === counter.name);
  const days = rec?.days ?? 0, total = rec?.total ?? 0;
  let headline = `${days} ${days === 1 ? 'day' : 'days'} in the current run`;
  if (total !== days) headline += `, ${total} ${total === 1 ? 'day' : 'days'} in total`;
  const out = [headline];
  const order = ['mild', 'strong', 'intense'];
  const urges = rows('RecoveryUrge').filter((u) => idOf(u.counterID) === counter._id && (() => { const d = resolveDate(u.date, now); return !!d && d >= since && d <= now; })());
  if (urges.length === 0) out.push('No urges logged');
  else {
    const strongest = urges.map((u) => enumOf(u.strength)).sort((a, b) => order.indexOf(b) - order.indexOf(a))[0];
    out.push(`${urges.length} ${urges.length === 1 ? 'urge' : 'urges'} logged, strongest felt ${strongest}`);
  }
  const fresh = (counter.runs ?? []).slice(1).filter((r: Row) => { const d = resolveDate(r.start, now); return !!d && d >= since && d <= now; }).length;
  if (fresh > 0) out.push(`${fresh} fresh ${fresh === 1 ? 'start' : 'starts'}`);
  return out;
}

/** AppointmentPrepView: everything the Session prep screen shows for one clinician. */
export function sessionPrep(id: string, now: Date = demoNow()) {
  const series = rows('AppointmentSeries').find((s) => s._id === id);
  if (!series) return null;
  const occ = (series.occurrences ?? []).map((o: Row) => ({ o, date: resolveDate(o.scheduledDate, now) })).filter((x: { date: Date | null }) => x.date) as { o: Row; date: Date }[];
  const next = occ.filter((x) => x.date > now).sort((a, b) => a.date.getTime() - b.date.getTime())[0];
  const last = occ.filter((x) => x.date <= now).sort((a, b) => b.date.getTime() - a.date.getTime())[0]?.date ?? null;
  const since = last ?? new Date(now.getTime() - Math.max(Number(series.typicalCadenceDays ?? 14), 7) * DAY);
  const own = new Set((series.occurrences ?? []).flatMap((o: Row) => [idOf(o.prepNoteEntryID), idOf(o.postSessionNoteEntryID)]).filter(Boolean));
  const entries = rows('JournalEntry').filter((e) => { const d = resolveDate(e.createdAt, now); return !!d && d >= since && !own.has(e._id) && entryText(e).trim() !== ''; });
  const checkIns = rows('CheckIn').filter((c) => { const d = resolveDate(c.timestamp, now); return !!d && d >= since; }).length;
  const bookmarked = entries.filter((e) => e.isFavorited).length;
  const plural = (n: number, one: string, many: string) => (n === 1 ? `1 ${one}` : `${n} ${many}`);
  const parts: string[] = [];
  if (entries.length) parts.push(plural(entries.length, 'journal entry', 'journal entries') + (bookmarked ? ` (${bookmarked} bookmarked)` : ''));
  if (checkIns) parts.push(plural(checkIns, 'check-in', 'check-ins'));
  const prepEntry = next ? rows('JournalEntry').find((e) => e._id === idOf(next.o.prepNoteEntryID)) : undefined;
  const eligible = entries.map((e) => ({ e, t: resolveDate(e.createdAt, now)!.getTime() })).sort((a, b) => b.t - a.t);
  const ordered = [...eligible.filter((x) => x.e.isFavorited), ...eligible.filter((x) => !x.e.isFavorited)].slice(0, 12);
  return {
    name: String(series.clinicianLabel),
    since: asDay(since),
    journalParts: parts.join(' and '),
    journalEntries: ordered.map((x) => { const line = previewLine(entryText(x.e)) ?? ''; return { id: String(x.e._id ?? x.t), day: asDay(new Date(x.t)), line: line.length > 140 ? line.slice(0, 140) + '...' : line, bookmarked: !!x.e.isFavorited }; }),
    about: String(series.notes ?? '').trim() || null,
    next: next ? formatAppointment(next.date) : null,
    sinceIsLast: !!last,
    recovery: rows('RecoveryCounter').filter((c) => !c.isArchived).sort(sortOrder).map((c) => ({ name: String(c.name), lines: recoveryLines(c, since, now) })),
    journalLine: `${parts.join(' and ')} since ${asDay(since)}.`,
    sleep: sleepLines(since, now),
    raise: rows('BridgeDraftItem').filter((i) => !i.isResolved && String(i.text ?? '').trim() && (!i.providerID || idOf(i.providerID) === id)).map((i) => ({ text: String(i.text), isQuestion: !!i.isQuestion })),
    bring: (next?.o.prepChecklist ?? []).map((i: Row) => ({ text: String(i.text), done: !!i.isDone })),
    prepNotes: prepEntry ? entryText(prepEntry) : '',
  };
}

/** The "Post-session notes" list: past sessions, newest first. */
export function postSessions(id: string, now: Date = demoNow()): { when: string; note: string }[] {
  const series = rows('AppointmentSeries').find((s) => s._id === id);
  return (series?.occurrences ?? []).map((o: Row) => ({ o, date: resolveDate(o.scheduledDate, now) })).filter((x: { date: Date | null }) => x.date && x.date <= now)
    .sort((a: { date: Date }, b: { date: Date }) => b.date.getTime() - a.date.getTime())
    .map((x: { o: Row; date: Date }) => ({ when: formatAppointment(x.date), note: idOf(x.o.postSessionNoteEntryID) ? 'Has notes' : 'No notes yet' }));
}

/** UnsentDraftsView */
export function unsentDraftRows(now: Date = demoNow()) {
  return rows('UnsentDraft').map((d) => ({ t: resolveDate(d.createdAt, now)?.getTime() ?? 0, to: String(d.recipientLabel ?? ''), text: String(d.text ?? ''), sent: !!d.wasSent })).sort((a, b) => b.t - a.t);
}

/** The Bridge draft list behind Things to raise: open items newest first, then resolved ones. */
export function bridgeDraftRows(now: Date = demoNow()) {
  const all = rows('BridgeDraftItem');
  const clinician = (i: Row) => (i.providerID ? String(rows('AppointmentSeries').find((s) => s._id === idOf(i.providerID))?.clinicianLabel ?? '') : '');
  const view = (i: Row) => ({ text: String(i.text), isQuestion: !!i.isQuestion, resolved: !!i.isResolved, answer: String(i.answer ?? ''), meta: [clinician(i) ? `For ${clinician(i)}` : '', asDay(resolveDate(i.createdAt, now) ?? now)].filter(Boolean).join(' \u00b7 ') });
  return [...all.filter((i) => !i.isResolved).reverse().map(view), ...all.filter((i) => i.isResolved).map(view)];
}

/** Counts per day for the Journal month and year views. */
export function journalCounts(now: Date = demoNow()) {
  const map = new Map<number, { entries: number; checkIns: number }>();
  for (const d of journalDays(now)) {
    const c = { entries: 0, checkIns: 0 };
    for (const it of d.items) it.kind === 'entry' ? c.entries++ : c.checkIns++;
    map.set(d.day.getTime(), c);
  }
  const earliest = [...map.keys()].sort((a, b) => a - b)[0] ?? now.getTime();
  return { map, earliest: new Date(earliest) };
}


/** A loop diagram: its steps in order, and whether each arrow means "more leads to more" (+) or "more leads to less" (-). */
export function loopDiagram(title: string) {
  const d = rows('FeedbackLoopDiagram').find((x) => x.title === title);
  const steps: { text: string; opposite: boolean }[] = (d?._steps ?? []).map((st: Row) => ({ text: String(st.text), opposite: st.link === 'opposite' }));
  if (steps.length === 0) return null;
  const opposites = steps.filter((x) => x.opposite).length;
  return {
    steps,
    closed: steps.length >= 2,
    name: opposites % 2 === 0 ? 'Reinforcing' : 'Balancing',
    sentence: opposites % 2 === 0 ? 'This one tends to keep itself going. Each time around, it adds to what it started with.' : 'This one tends to settle back. Each time around, it pushes against where it started.',
  };
}

/** The counter detail screen's start: whole days on the current run and the next milestone, worked out like the cards on Now. */
export function counterDetail(name: string, now: Date = demoNow()) {
  const c = recoveryHome(now).find((x) => x.name === name);
  const next = [1, 3, 7, 14, 21, 30, 60, 90, 120, 180, 270, 365].find((m) => m > (c?.days ?? 0)) ?? 365;
  return c ? { name: c.name, days: c.days, next } : null;
}

/** One grounding tool for its editor sheet. */
export function groundingToolDetail(title: string) {
  const t = rows('GroundingTool').find((x) => x.title === title);
  if (!t) return null;
  const windows = (t.relevantTimeWindows ?? []).map((w: unknown) => enumOf(w));
  return { title: String(t.title), steps: String(t.steps ?? ''), deepLink: enumOf(t.kind) === 'deepLink', windows };
}
