import type { ReactNode } from 'react';
import { WidgetFooter, WidgetPair, type Tint } from '../AnchorUI';
import layout from '../../../content/widgets.generated.json';

/**
 * WidgetStack: lays a widget tab out the way the app does. Which widgets show, in what order, which pair two to a row and which are
 * tucked under "More" all come from widgets.generated.json, which scripts/sync-widgets.mjs reads from the Swift (WidgetID and WidgetTab).
 */
export type WidgetMeta = { title: string; icon: string; tint: Tint; half: boolean };
export const widgetTable = layout.widgets as unknown as Record<string, WidgetMeta>;

export default function WidgetStackView({ tab, render }: { tab: 'plan' | 'bridge' | 'thread'; render: (id: string, meta: WidgetMeta) => ReactNode }) {
  const { order, hidden: hiddenList } = layout.tabs[tab];
  const hidden = new Set(hiddenList);
  const visible = order.filter((id) => !hidden.has(id));
  const rows: string[][] = [];
  for (let i = 0; i < visible.length; i++) {
    const a = visible[i], b = visible[i + 1];
    if (widgetTable[a].half && b && widgetTable[b].half) { rows.push([a, b]); i++; } else rows.push([a]);
  }
  const tucked = order.filter((id) => hidden.has(id)).map((id) => ({ id, icon: widgetTable[id].icon, title: widgetTable[id].title, tint: widgetTable[id].tint }));
  return (
    <div className="au-widget-stack">
      {rows.map((row) => row.length === 2
        ? <WidgetPair key={row.join('+')} left={render(row[0], widgetTable[row[0]])} right={render(row[1], widgetTable[row[1]])} />
        : <div key={row[0]}>{render(row[0], widgetTable[row[0]])}</div>)}
      <WidgetFooter tucked={tucked} />
    </div>
  );
}
