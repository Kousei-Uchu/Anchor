import { useEffect, useId, useRef } from 'react';

/**
 * Anchor's little character. Same shape and colours as the promo video's mascot.
 * Blinks and breathes with CSS; on devices with a mouse, its eyes follow the pointer.
 */
export function Mascot({ size = 120, follow = true }: { size?: number; follow?: boolean }) {
  const uid = useId().replace(/:/g, '');
  const ref = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!follow) return;
    const fine = window.matchMedia('(pointer: fine)').matches;
    const calm = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!fine || calm) return;
    let raf = 0;
    const move = (e: PointerEvent) => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const el = ref.current;
        if (!el) return;
        const r = el.getBoundingClientRect();
        const dx = e.clientX - (r.left + r.width / 2);
        const dy = e.clientY - (r.top + r.height / 2);
        const d = Math.hypot(dx, dy) || 1;
        const k = Math.min(1, d / 280);
        el.style.setProperty('--gx', String((dx / d) * k));
        el.style.setProperty('--gy', String((dy / d) * k));
      });
    };
    window.addEventListener('pointermove', move, { passive: true });
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('pointermove', move);
    };
  }, [follow]);

  return (
    <svg
      ref={ref}
      className="mascot"
      width={size}
      height={(size * 740) / 720}
      viewBox="152 150 720 740"
      role="img"
      aria-label="Anchor's mascot"
    >
      <defs>
        <linearGradient id={`${uid}b`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#EBA58C" />
          <stop offset="1" stopColor="#C86C52" />
        </linearGradient>
        <radialGradient id={`${uid}h`} cx="0.3" cy="0.18" r="0.65">
          <stop offset="0" stopColor="#fff" stopOpacity="0.38" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
      </defs>
      <g className="mascot-body">
        <rect x="152" y="150" width="720" height="740" rx="280" fill={`url(#${uid}b)`} />
        <rect x="152" y="150" width="720" height="740" rx="280" fill={`url(#${uid}h)`} />
        <g className="mascot-face">
          <rect className="mascot-eye" x="354" y="330" width="84" height="148" rx="42" fill="#FFF9F3" />
          <rect className="mascot-eye" x="586" y="330" width="84" height="148" rx="42" fill="#FFF9F3" />
          <g transform="translate(440 640) scale(1.5)" fill="none" stroke="#FFF9F3" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="50" cy="11" r="8.5" />
            <line x1="50" y1="19.5" x2="50" y2="104" />
            <line x1="36" y1="31" x2="64" y2="31" />
            <path d="M 16 76 C 16 98 33 107 50 107 C 67 107 84 98 84 76" />
            <path d="M 8 87 L 16 75 L 26 86" />
            <path d="M 92 87 L 84 75 L 74 86" />
          </g>
        </g>
      </g>
    </svg>
  );
}
