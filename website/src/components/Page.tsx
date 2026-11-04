import type { ReactNode } from 'react';
import { usePageMeta } from '../hooks/usePageMeta';
import { ROUTE_META } from '../content/meta';

/** Shell for the plain reading pages (privacy, support). Server-rendered, so it works without JavaScript. */
export function Page({ route, title, meta, children }: { route: string; title: string; meta?: string; children: ReactNode }) {
  const m = ROUTE_META[route];
  usePageMeta(m.title, m.description);
  return (
    <main className="prose">
      <h1>{title}</h1>
      {meta && <p className="meta">{meta}</p>}
      {children}
      <div className="panel callout">
        <strong>Early build.</strong> Anchor is not finished and parts may change. The data policy will not: Anchor sends no data, or the bare minimum if a feature ever needs it, and if that ever changes you will be told immediately in the app.
      </div>
    </main>
  );
}
