import { useState, type ReactNode } from 'react';
import { CheckInRowCard, DayMarker, EntryCard, SearchField, Segmented, TimelineRow } from '../AnchorUI';
import { formatClock, journalDays } from '../../../content/seed';

/**
 * The Journal tab: JournalView.swift's timeline. The title, search field and Days / Month / Year control stay fixed while the entries scroll.
 * Entries and check-ins come from the app's demo data, newest first and grouped by day. Month and Year are not rebuilt yet.
 */
export function useJournalTab(): { pinned: ReactNode; body: ReactNode } {
  const [query, setQuery] = useState('');
  const [layout, setLayout] = useState('Days');
  const days = journalDays();
  const q = query.trim().toLowerCase();

  const pinned = (
    <>
      <SearchField value={query} onChange={setQuery} prompt="Search your journal" />
      <Segmented options={['Days', 'Month', 'Year']} value={layout} onChange={setLayout} />
    </>
  );

  let body: ReactNode;
  if (layout !== 'Days') {
    body = <div className="au-subheadline au-secondary au-journal-empty">The {layout} view is not rebuilt yet.</div>;
  } else {
    const shown = days
      .map((d) => ({ ...d, items: d.items.filter((it) => (it.kind === 'entry' ? !q || (it.preview ?? '').toLowerCase().includes(q) : !q)) }))
      .filter((d) => d.items.length > 0);
    body = shown.length === 0
      ? <div className="au-subheadline au-secondary au-journal-empty">{q ? `No entries match "${query.trim()}".` : 'Nothing here yet. Tap the pencil to write.'}</div>
      : shown.map((d) => (
        <div key={d.day.getTime()} className="au-day-group">
          <DayMarker day={String(d.day.getDate())} month={new Intl.DateTimeFormat('en-AU', { month: 'short' }).format(d.day)} />
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
