import { useEffect, useState, type ComponentType } from 'react';

/**
 * Loads the demo in the browser only. The rebuilt app works out dates from today, so it is not drawn into the prerendered pages, and
 * its data is kept out of the main bundle until a visitor is about to see it.
 */
type Props = { tab?: number; scrollTo?: number; locked?: boolean };

export function DemoPhone(props: Props) {
  const [Loaded, setLoaded] = useState<ComponentType<Props> | null>(null);
  useEffect(() => {
    let live = true;
    import('./ios/DemoPhone').then((m) => { if (live) setLoaded(() => m.default); });
    return () => { live = false; };
  }, []);
  return Loaded ? <Loaded {...props} /> : <div className="au-placeholder" role="img" aria-label="Loading the Anchor demo" />;
}
