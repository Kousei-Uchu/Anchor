import { useEffect, useState } from 'react';

/** Height of the small viewport (address bar showing). Unlike innerHeight it does not change while scrolling. */
function stableHeight() {
  const probe = document.createElement('div');
  probe.style.cssText = 'position:fixed;top:0;left:0;width:0;height:100svh;visibility:hidden;pointer-events:none';
  document.body.appendChild(probe);
  const h = probe.offsetHeight;
  probe.remove();
  return h || window.innerHeight;
}

/**
 * Viewport size. Server render and first paint assume a typical laptop.
 * Mobile browsers fire `resize` every time the address bar collapses or expands, so height-only changes
 * are ignored unless they are big (rotation, split screen, desktop window resize).
 */
export function useViewportSize() {
  const [size, setSize] = useState({ w: 1280, h: 800 });
  useEffect(() => {
    let lastW = 0;
    let lastH = 0;
    const read = () => {
      const w = window.innerWidth;
      const h = stableHeight();
      if (lastW && w === lastW && Math.abs(h - lastH) < 120) return;
      lastW = w;
      lastH = h;
      setSize({ w, h });
    };
    read();
    window.addEventListener('resize', read);
    window.addEventListener('orientationchange', read);
    return () => {
      window.removeEventListener('resize', read);
      window.removeEventListener('orientationchange', read);
    };
  }, []);
  return size;
}
