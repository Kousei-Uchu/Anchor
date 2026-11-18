import { useState, type ReactNode } from 'react';
import { CheckInRowCard, DayMarker, EntryCard, Glyph, SearchField, Segmented, TimelineRow } from '../AnchorUI';
import { demoNow, formatClock, journalCounts, journalDays, monthShort, startOfDay } from '../../../content/seed';

/**
 * The Journal tab: JournalView.swift's timeline. The title, search field and Days / Month / Year control stay fixed while the entries scroll.
 * Entries and check-ins come from the app's demo data, newest first and grouped by day. Month and Year follow JournalMonthView and JournalYearView.
 */
const WEEKDAYS = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];
const monthLong = (d: Date) => new Intl.DateTimeFormat('en-AU', { month: 'long' }).format(d);
const firstOfMonth = (d: Date) => new Date(d.getFullYear(), d.getMonth(), 1);
const daysIn = (first: Date) => new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();

/** The arrows and title above the month and year grids. */
function PeriodHeader({ title, canBack, canForward, onShift }: { title: string; canBack: boolean; canForward: boolean; onShift: (by: number) => void }) {
  return (
    <div className="au-period">
      <button type="button" disabled={!canBack} onClick={() => onShift(-1)} aria-label="Earlier"><Glyph name="chevron.left" size={22} weight={2.4} /></button>
      <span className="au-headline">{title}</span>
      <button type="button" disabled={!canForward} onClick={() => onShift(1)} aria-label="Later"><Glyph name="chevron.right" size={22} weight={2.4} /></button>
    </div>
  );
}

/** JournalMonthView: one month, with a dot for each entry (up to three), a square if there was a check-in, and today marked. */
function MonthView({ month, setMonth }: { month: Date; setMonth: (d: Date) => void }) {
  const { map, earliest } = journalCounts();
  const today = startOfDay(demoNow());
  const current = firstOfMonth(today);
  const lead = (month.getDay() + 6) % 7;
  const cells: (Date | null)[] = [...Array(lead).fill(null), ...Array.from({ length: daysIn(month) }, (_, i) => new Date(month.getFullYear(), month.getMonth(), i + 1))];
  return (
    <div className="au-stack-12" style={{ width: '100%' }}>
      <PeriodHeader title={`${monthLong(month)} ${month.getFullYear()}`} canBack={month > firstOfMonth(earliest)} canForward={month < current}
        onShift={(by) => setMonth(new Date(month.getFullYear(), month.getMonth() + by, 1))} />
      <div className="au-monthgrid">
        {WEEKDAYS.map((w) => <span key={w} className="au-caption2 au-semibold au-secondary au-center">{w}</span>)}
        {cells.map((d, i) => {
          if (!d) return <span key={i} className="au-daycell" />;
          const c = map.get(d.getTime());
          const has = !!c && c.entries + c.checkIns > 0;
          const isToday = d.getTime() === today.getTime();
          return (
            <span key={i} className={`au-daycell${isToday ? ' au-daycell-today' : ''}`}>
              <span className={`au-daynum${has || isToday ? '' : ' au-secondary'}`} style={isToday ? { fontWeight: 700 } : undefined}>{d.getDate()}</span>
              <span className="au-daydots">
                {Array.from({ length: Math.min(c?.entries ?? 0, 3) }, (_, k) => <i key={k} className="au-dot" />)}
                {(c?.checkIns ?? 0) > 0 && <i className="au-sq" />}
              </span>
            </span>
          );
        })}
      </div>
      <div className="au-legend"><span><i className="au-dot" />Entry</span><span><i className="au-sq" />Check-in</span></div>
    </div>
  );
}

/** JournalYearView: twelve small months, each day a square shaded by how much is written. */
function YearView({ year, setYear, onPickMonth }: { year: number; setYear: (y: number) => void; onPickMonth: (d: Date) => void }) {
  const { map, earliest } = journalCounts();
  const today = startOfDay(demoNow());
  return (
    <div className="au-stack-12" style={{ width: '100%' }}>
      <PeriodHeader title={String(year)} canBack={year > earliest.getFullYear()} canForward={year < today.getFullYear()} onShift={(by) => setYear(year + by)} />
      <div className="au-yeargrid">
        {Array.from({ length: 12 }, (_, m) => {
          const first = new Date(year, m, 1);
          const future = first > firstOfMonth(today);
          const lead = (first.getDay() + 6) % 7;
          return (
            <button key={m} type="button" className={`au-minimonth${future ? ' au-future' : ''}`} disabled={future} onClick={() => onPickMonth(first)}>
              <span className="au-caption au-semibold" style={{ color: future ? 'var(--au-secondary)' : undefined }}>{monthShort(first)}</span>
              <span className="au-minigrid">
                {Array(lead).fill(0).map((_, i) => <i key={`l${i}`} className="au-minilead" />)}
                {Array.from({ length: daysIn(first) }, (_, i) => {
                  const c = map.get(new Date(year, m, i + 1).getTime());
                  const n = (c?.entries ?? 0) + (c?.checkIns ?? 0);
                  return <i key={i} className={`au-miniday au-shade-${n === 0 ? 0 : n === 1 ? 1 : 2}`} />;
                })}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function useJournalTab(): { pinned: ReactNode; body: ReactNode } {
  const [query, setQuery] = useState('');
  const [layout, setLayout] = useState('Days');
  const [month, setMonth] = useState(() => firstOfMonth(startOfDay(demoNow())));
  const days = journalDays();
  const q = query.trim().toLowerCase();

  const pinned = (
    <>
      <SearchField value={query} onChange={setQuery} prompt="Search your journal" />
      <Segmented options={['Days', 'Month', 'Year']} value={layout} onChange={setLayout} />
    </>
  );

  let body: ReactNode;
  if (layout === 'Month') {
    body = <MonthView month={month} setMonth={setMonth} />;
  } else if (layout === 'Year') {
    body = <YearView year={month.getFullYear()} setYear={(y) => setMonth(new Date(y, month.getMonth(), 1))} onPickMonth={(d) => { setMonth(d); setLayout('Month'); }} />;
  } else {
    const shown = days
      .map((d) => ({ ...d, items: d.items.filter((it) => (it.kind === 'entry' ? !q || (it.preview ?? '').toLowerCase().includes(q) : !q)) }))
      .filter((d) => d.items.length > 0);
    body = shown.length === 0
      ? <div className="au-subheadline au-secondary au-journal-empty">{q ? `No entries match "${query.trim()}".` : 'Nothing here yet. Tap the pencil to write.'}</div>
      : shown.map((d) => (
        <div key={d.day.getTime()} className="au-day-group">
          <DayMarker day={String(d.day.getDate())} month={monthShort(d.day)} />
          {d.items.map((it) => (
            <TimelineRow key={`${it.kind}-${it.time.getTime()}`} checkIn={it.kind === 'checkin'}>
              {it.kind === 'entry'
                ? <EntryCard time={formatClock(it.time)} bookmarked={it.bookmarked} preview={it.preview} chips={it.chips} />
                : <CheckInRowCard time={formatClock(it.time)} answered={it.answered} readings={it.readings} />}
            </TimelineRow>
          ))}
        </div>
      ));
  }
  return { pinned, body };
}
