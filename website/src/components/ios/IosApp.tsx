import { useState, type ReactNode } from 'react';
import { AnchorScreen, type Toolbar } from './AnchorUI';
import NowTab from './tabs/NowTab';
import PlanTab from './tabs/PlanTab';
import BridgeTab from './tabs/BridgeTab';
import ThreadTab from './tabs/ThreadTab';
import { useJournalTab } from './tabs/JournalTab';

/**
 * The app's five tabs. Each one says what its toolbar holds, how far its content sits below the title, and whether part of it is pinned.
 */
type Parts = { toolbar?: Toolbar; inset: number; pinned?: ReactNode; body: ReactNode };

function useNow(): Parts { return { inset: 16, body: <NowTab /> }; }
function usePlan(): Parts { return { toolbar: { trailing: ['gearshape', 'questionmark.circle'] }, inset: 8, body: <PlanTab /> }; }
function useJournal(): Parts { return { toolbar: { leading: ['questionmark.circle'], trailing: ['square.and.pencil', 'ellipsis'] }, inset: 0, ...useJournalTab() }; }
const useBridge = (): Parts => ({ toolbar: { trailing: ['square.and.arrow.up', 'questionmark.circle'] }, inset: 8, body: <BridgeTab /> });
const useThread = (): Parts => ({ inset: 8, body: <ThreadTab /> });
const TABS: Record<string, () => Parts> = { Now: useNow, Plan: usePlan, Journal: useJournal, Bridge: useBridge, Thread: useThread };

/** Isolated per tab so each tab's own state starts fresh when it is opened. */
function ActiveTab({ tab, onTab, scheme, full }: { tab: string; onTab: (t: string) => void; scheme: 'light' | 'dark'; full: boolean }) {
  const t = TABS[tab]();
  return <AnchorScreen title={tab} tab={tab} onTab={onTab} toolbar={t.toolbar} pinned={t.pinned} inset={t.inset} scheme={scheme} full={full}>{t.body}</AnchorScreen>;
}

export default function IosApp({ initialTab = 'Now', scheme = 'light', full = false }: { initialTab?: string; scheme?: 'light' | 'dark'; full?: boolean }) {
  const [tab, setTab] = useState(initialTab in TABS ? initialTab : 'Now');
  return <ActiveTab key={tab} tab={tab} onTab={setTab} scheme={scheme} full={full} />;
}
