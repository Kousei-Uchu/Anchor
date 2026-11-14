import { useState, type ReactNode } from 'react';
import { AnchorScreen, type Toolbar } from './AnchorUI';
import { NavContext, type Nav } from './nav';
import NowTab from './tabs/NowTab';
import PlanTab from './tabs/PlanTab';
import BridgeTab from './tabs/BridgeTab';
import ThreadTab from './tabs/ThreadTab';
import { useJournalTab } from './tabs/JournalTab';
import { useAffirmations, useContacts, useDeEscalation, useGrounding, type DetailParts } from './screens/ListScreens';

/**
 * The app's five tabs, each with its own stack of pushed screens like the NavigationStack each tab has in the app.
 * A tab says what its toolbar holds, how far its content sits below the title, and whether part of it is pinned.
 */
type Parts = { toolbar?: Toolbar; inset: number; pinned?: ReactNode; body: ReactNode };

function useNow(): Parts { return { inset: 16, body: <NowTab /> }; }
function usePlan(): Parts { return { toolbar: { trailing: ['gearshape', 'questionmark.circle'] }, inset: 8, body: <PlanTab /> }; }
function useJournal(): Parts { return { toolbar: { leading: ['questionmark.circle'], trailing: ['square.and.pencil', 'ellipsis'] }, inset: 0, ...useJournalTab() }; }
const useBridge = (): Parts => ({ toolbar: { trailing: ['square.and.arrow.up', 'questionmark.circle'] }, inset: 8, body: <BridgeTab /> });
const useThread = (): Parts => ({ inset: 8, body: <ThreadTab /> });
const TABS: Record<string, () => Parts> = { Now: useNow, Plan: usePlan, Journal: useJournal, Bridge: useBridge, Thread: useThread };

/** Pushed screens, by the name a screen passes to nav.push(). */
const DETAILS: Record<string, () => DetailParts> = {
  contacts: useContacts, grounding: useGrounding, deescalation: useDeEscalation, affirmations: useAffirmations,
};

type Common = { scheme: 'light' | 'dark'; full: boolean; onTab: (t: string) => void };

/** Isolated per tab so each tab's own state starts fresh when it is opened. */
function ActiveTab({ tab, scheme, full, onTab }: Common & { tab: string }) {
  const t = TABS[tab]();
  return <AnchorScreen title={tab} tab={tab} onTab={onTab} toolbar={t.toolbar} pinned={t.pinned} inset={t.inset} scheme={scheme} full={full}>{t.body}</AnchorScreen>;
}

function DetailView({ id, tab, onBack, scheme, full, onTab }: Common & { id: string; tab: string; onBack: () => void }) {
  const d = DETAILS[id]();
  return <AnchorScreen title={d.title} tab={tab} onTab={onTab} onBack={onBack} toolbar={d.toolbar} inset={d.inset} scheme={scheme} full={full}>{d.body}</AnchorScreen>;
}

export default function IosApp({ initialTab = 'Now', initialScreen, scheme = 'light', full = false }: { initialTab?: string; initialScreen?: string; scheme?: 'light' | 'dark'; full?: boolean }) {
  const first = initialTab in TABS ? initialTab : 'Now';
  const [tab, setTab] = useState(first);
  const [stacks, setStacks] = useState<Record<string, string[]>>(initialScreen && initialScreen in DETAILS ? { [first]: [initialScreen] } : {});
  const stack = stacks[tab] ?? [];
  const nav: Nav = {
    push: (id) => { if (id in DETAILS) setStacks((s) => ({ ...s, [tab]: [...(s[tab] ?? []), id] })); },
    pop: () => setStacks((s) => ({ ...s, [tab]: (s[tab] ?? []).slice(0, -1) })),
  };
  // Tapping the tab you are on goes back to its first screen, as in iOS.
  const onTab = (t: string) => (t === tab ? setStacks((s) => ({ ...s, [t]: [] })) : setTab(t));
  const top = stack[stack.length - 1];
  return (
    <NavContext.Provider value={nav}>
      <div style={{ display: top ? 'none' : undefined }}><ActiveTab key={tab} tab={tab} scheme={scheme} full={full} onTab={onTab} /></div>
      {top && <DetailView key={`${tab}/${stack.join('/')}`} id={top} tab={tab} onBack={nav.pop} scheme={scheme} full={full} onTab={onTab} />}
    </NavContext.Provider>
  );
}
