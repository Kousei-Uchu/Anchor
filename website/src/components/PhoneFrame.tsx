import type { ReactNode } from 'react';

export const DEVICE_W = 413;
export const DEVICE_H = 872;

/** A phone body sized to `scale`. The content is laid out at full size, then scaled, so it never reflows. */
export function PhoneFrame({ scale, children }: { scale: number; children: ReactNode }) {
  return (
    <div className="pf" style={{ width: DEVICE_W * scale, height: DEVICE_H * scale }}>
      <div className="dev" style={{ transform: `scale(${scale})` }}>
        {children}
      </div>
    </div>
  );
}
