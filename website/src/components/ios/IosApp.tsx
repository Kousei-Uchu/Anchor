import { useState, type ReactNode } from 'react';
import { AnchorScreen, Card } from './AnchorUI';
import NowTab from './tabs/NowTab';
import PlanTab from './tabs/PlanTab';

/** The app's five tabs. Tabs that are not rebuilt yet say so (this is only shown in development). */
const Soon = ({ name }: { name: string }) => <Card><div className="au-subheadline">The {name} tab is not rebuilt yet.</div></Card>;
const TABS: Record<string, { gear?: boolean; inset: number; content: ReactNode }> = {
  Now: { inset: 16, content: <NowTab /> },
  Plan: { gear: true, inset: 8, content: <PlanTab /> },
  Journal: { inset: 16, content: <Soon name="Journal" /> },
  Bridge: { inset: 16, content: <Soon name="Bridge" /> },
  Thread: { inset: 16, content: <Soon name="Thread" /> },
};

export default function IosApp({ initialTab = 'Now', scheme = 'light', full = false }: { initialTab?: string; scheme?: 'light' | 'dark'; full?: boolean }) {
  const [tab, setTab] = useState(initialTab in TABS ? initialTab : 'Now');
  const t = TABS[tab];
  return (
    <AnchorScreen key={tab} title={tab} tab={tab} onTab={setTab} gear={t.gear} inset={t.inset} scheme={scheme} full={full}>
      {t.content}
    </AnchorScreen>
  );
}
