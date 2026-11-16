import { useEffect, useState } from 'react';
import IosApp from './IosApp';

/**
 * The demo as it appears on the website: the rebuilt app inside the phone, with a dynamic island on top.
 * `tab` (0 to 4), `scrollTo` and `locked` let the intro on the home page drive it. With none of them it is fully tappable.
 * It follows the visitor's light or dark setting.
 */
const TAB_NAMES = ['Now', 'Plan', 'Journal', 'Bridge', 'Thread'];

function usePrefersDark() {
  const [dark, setDark] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const read = () => setDark(mq.matches);
    read();
    mq.addEventListener('change', read);
    return () => mq.removeEventListener('change', read);
  }, []);
  return dark;
}

export default function DemoPhone({ tab, scrollTo, locked }: { tab?: number; scrollTo?: number; locked?: boolean }) {
  const dark = usePrefersDark();
  return (
    <div className="au-demo">
      <IosApp controlledTab={tab === undefined ? undefined : TAB_NAMES[tab]} scrollTo={scrollTo} locked={locked} scheme={dark ? 'dark' : 'light'} />
      <span className="au-island" aria-hidden="true" />
    </div>
  );
}
