import { Suspense, lazy, useEffect, useRef, useState } from 'react';
import { Reveal } from '../components/Reveal';
import { Icon } from '../components/Icons';

// The Remotion player (and the whole promo) loads only when this section is about to be seen.
const PromoPlayer = lazy(() => import('../components/PromoPlayer'));

const SHOTS = [1, 2, 3, 4, 5, 6];

export function Showcase() {
  const ref = useRef<HTMLElement>(null);
  const [near, setNear] = useState(false);
  const [view, setView] = useState<'story' | 'app'>('story');
  const [videoOk, setVideoOk] = useState(true);
  const [promoFile, setPromoFile] = useState(true);
  const [missing, setMissing] = useState<Set<number>>(new Set());

  useEffect(() => {
    const el = ref.current;
    if (!el || !('IntersectionObserver' in window)) return setNear(true);
    const io = new IntersectionObserver(([e]) => e.isIntersecting && (setNear(true), io.disconnect()), { rootMargin: '600px 0px' });
    io.observe(el);
    return () => io.disconnect();
  }, []);

  const shots = SHOTS.filter((n) => !missing.has(n));

  return (
    <section className="section showcase" id="video" ref={ref}>
      <Reveal>
        <p className="eyebrow">Take a look</p>
        <h2>See it in action</h2>
        <p className="lead">A one-minute story with a little music, and a recording from the real app.</p>
      </Reveal>

      {videoOk && (
        <div className="seg" role="tablist" aria-label="Choose what to watch">
          <button type="button" role="tab" aria-selected={view === 'story'} className={view === 'story' ? 'on' : ''} onClick={() => setView('story')}>The story</button>
          <button type="button" role="tab" aria-selected={view === 'app'} className={view === 'app' ? 'on' : ''} onClick={() => setView('app')}>The real app</button>
        </div>
      )}

      <div className="stage-card">
        {view === 'story' ? (
          <div className="promo">
            <div className="promo-frame">
              {near && promoFile ? (
                <video
                  className="promo-video"
                  src="/assets/media/anchor-promo.mp4"
                  controls
                  playsInline
                  loop
                  preload="metadata"
                  aria-label="Anchor promo video"
                  onError={() => setPromoFile(false)}
                />
              ) : near ? (
                <Suspense fallback={<div className="promo-wait"><Icon name="play" /></div>}>
                  <PromoPlayer />
                </Suspense>
              ) : (
                <div className="promo-wait"><Icon name="play" /></div>
              )}
            </div>
            <p className="hint">Press play. It has gentle music, so you may want your volume up.</p>
          </div>
        ) : (
          <div className="rec">
            <div className="vf">
              <video src="/assets/media/anchor-demo.mp4" muted loop playsInline autoPlay preload="metadata" onError={() => setVideoOk(false)} aria-label="Screen recording of the Anchor app" />
            </div>
            <p className="hint">Recorded from the real app, with made-up content.</p>
          </div>
        )}
      </div>

      {shots.length > 0 && (
        <div className="shots" tabIndex={0} aria-label="Screenshots from the app">
          {shots.map((n) => (
            <img
              key={n}
              src={`/assets/media/shot-${n}.png`}
              alt={`Anchor screenshot ${n}`}
              loading="lazy"
              decoding="async"
              onError={() => setMissing((m) => new Set(m).add(n))}
            />
          ))}
        </div>
      )}
    </section>
  );
}
