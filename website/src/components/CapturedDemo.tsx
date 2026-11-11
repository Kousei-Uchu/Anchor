import { useEffect, useRef, useState } from 'react';
import data from '../content/demo.screens.generated.json';
import { DemoApp } from './DemoApp';

// The tappable demo made from recordings of the real app (Patch 55b). The pictures and the tappable areas
// come from scripts/make-demo-capture.sh and scripts/sync-demo-screens.mjs. Nothing in the screens is typed by hand.
// Until the app has been recorded the list is empty, and Demo falls back to the hand-built DemoApp.

type Hot = { x: number; y: number; w: number; h: number; label: string; to?: string; back?: boolean };
type Screen = { id: string; image: string; hot: Hot[]; more?: string; less?: string };

const screens = data.screens as unknown as Screen[];
const start = (data as { start?: string }).start ?? 'now';
const byId = new Map(screens.map((s) => [s.id, s]));

export const hasCapturedDemo = byId.has(start);

function CapturedDemo() {
  const [stack, setStack] = useState<string[]>([start]);
  const touchY = useRef<number | null>(null);
  const cur = byId.get(stack[stack.length - 1]) ?? byId.get(start)!;

  // Load every picture once the page is idle, so a tap never waits for one.
  useEffect(() => {
    const load = () => screens.forEach((s) => { new Image().src = s.image; });
    const idle = (window as { requestIdleCallback?: (f: () => void) => number }).requestIdleCallback;
    if (idle) idle(load);
    else window.setTimeout(load, 600);
  }, []);

  const go = (id: string) => setStack((s) => [...s, id]);
  const back = () => setStack((s) => (s.length > 1 ? s.slice(0, -1) : s));
  const swap = (id?: string) => id && setStack((s) => [...s.slice(0, -1), id]);

  return (
    <div
      className="cd"
      role="group"
      aria-label="Anchor demo, recorded from the real app"
      onWheel={(e) => {
        if (e.deltaY > 30) swap(cur.more);
        else if (e.deltaY < -30) swap(cur.less);
      }}
      onTouchStart={(e) => { touchY.current = e.touches[0].clientY; }}
      onTouchEnd={(e) => {
        if (touchY.current === null) return;
        const dy = e.changedTouches[0].clientY - touchY.current;
        touchY.current = null;
        if (dy < -40) swap(cur.more);
        else if (dy > 40) swap(cur.less);
      }}
    >
      <img src={cur.image} alt="" draggable={false} />
      {cur.hot.map((h, i) => (
        <button
          type="button"
          key={`${h.label}-${i}`}
          className="hot"
          aria-label={h.label.split(',')[0]}
          style={{ left: `${h.x}%`, top: `${h.y}%`, width: `${h.w}%`, height: `${h.h}%` }}
          onClick={() => (h.back ? back() : h.to && go(h.to))}
        />
      ))}
      {cur.more && (
        <button type="button" className="cd-scroll" onClick={() => swap(cur.more)}>Scroll down</button>
      )}
      {cur.less && (
        <button type="button" className="cd-scroll up" onClick={() => swap(cur.less)}>Scroll up</button>
      )}
    </div>
  );
}

/** The recorded demo if there is one, otherwise the hand-built one. */
export function Demo() {
  return hasCapturedDemo ? <CapturedDemo /> : <DemoApp />;
}
