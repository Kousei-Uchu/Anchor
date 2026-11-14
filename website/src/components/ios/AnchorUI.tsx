import { useState, type ReactNode } from 'react';
import '@fontsource-variable/nunito';
import '@fontsource-variable/nunito/wght-italic.css';
import '../../styles/design.generated.css';
import './anchor-ui.css';

/** Mirrors Anchor.Theme tints. The colours themselves come from design.generated.css. */
export type Tint = 'accent' | 'sage';
const tintStyle = (tint: Tint) => ({ ['--tint' as string]: `var(--anchor-${tint})` });

/**
 * Icons drawn for the website. SF Symbols cannot be used off Apple platforms, so each name below is the
 * SF Symbol the app uses, redrawn by hand in the same filled or outlined style.
 */
const F = 'currentColor';
const GLYPHS: Record<string, (w: number) => ReactNode> = {
  'circle.hexagongrid.fill': () => (<g fill={F}><circle cx="12" cy="12" r="3.2" />{[0, 60, 120, 180, 240, 300].map((a) => <circle key={a} cx={12 + 6.6 * Math.cos((a * Math.PI) / 180)} cy={12 + 6.6 * Math.sin((a * Math.PI) / 180)} r="3.2" />)}</g>),
  'calendar.badge.clock': () => <path fill={F} fillRule="evenodd" d="M7 2.5a1 1 0 0 1 1 1V5h8V3.5a1 1 0 1 1 2 0V5h.5A3.5 3.5 0 0 1 22 8.5v10a3.5 3.5 0 0 1-3.5 3.5h-13A3.5 3.5 0 0 1 2 18.5v-10A3.5 3.5 0 0 1 5.5 5H6V3.5a1 1 0 0 1 1-1zM4 10v8.5c0 .8.7 1.5 1.5 1.5h13c.8 0 1.5-.7 1.5-1.5V10z" />,
  'shield.fill': () => <path fill={F} d="M12 2l8 3v6c0 5-3.4 9.2-8 11-4.6-1.8-8-6-8-11V5z" />,
  'phone.fill': () => <path fill={F} d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2c.3-.3.7-.4 1-.2 1.1.4 2.3.6 3.6.6.6 0 1 .4 1 1V20c0 .6-.4 1-1 1C10.6 21 3 13.4 3 4c0-.6.4-1 1-1h3.5c.6 0 1 .4 1 1 0 1.3.2 2.5.6 3.6.1.3 0 .7-.2 1l-2.3 2.2z" />,
  'message.fill': () => <path fill={F} d="M12 3C6.5 3 2 6.6 2 11c0 2.2 1.1 4.2 2.9 5.6L3.8 21l4.7-2.3c1.1.3 2.3.5 3.5.5 5.5 0 10-3.6 10-8.1S17.5 3 12 3z" />,
  'cross.case.fill': () => <path fill={F} fillRule="evenodd" d="M9 7V5.5A2.5 2.5 0 0 1 11.5 3h1A2.5 2.5 0 0 1 15 5.5V7h4a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-8a3 3 0 0 1 3-3zm1.5 0h3V5.5a.5.5 0 0 0-.5-.5h-2a.5.5 0 0 0-.5.5zM11 11.5v2H9v2h2v2h2v-2h2v-2h-2v-2z" />,
  'leaf.fill': () => <path fill={F} d="M20.5 3.5C11 3.5 4.5 8.5 4.5 16.5c0 1 .2 2 .5 2.9L3.5 21l1.5.5 1.6-1.6c.9.3 1.9.5 2.9.5C17.5 20.4 20.5 13 20.5 3.5z" />,
  'list.number': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round"><path d="M10 6h11M10 12h11M10 18h11" /><path d="M3.5 5l1.5-1v4M3.5 11.5h3l-3 3h3M3.5 17.5h2.5l-1.2 1.2c1 0 1.5.5 1.5 1.1 0 .7-.7 1.2-1.8 1.2h-1" strokeWidth="1.3" /></g>,
  'chevron.right': (w) => <path fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" d="M9 6l6 6-6 6" />,
  globe: (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round"><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18" /></g>,
  'questionmark.circle': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9.5" /><path d="M9.5 9.5a2.6 2.6 0 1 1 3.7 2.3c-.8.4-1.2 1-1.2 1.9" /><circle cx="12" cy="17" r=".5" fill={F} /></g>,
  anchor: (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round"><circle cx="12" cy="5" r="2" /><path d="M12 7v14M8 11h8M4 14c0 4 3.5 7 8 7s8-3 8-7" /></g>,
  'sun.max.fill': () => <g fill={F}><circle cx="12" cy="12" r="4.5" /><path stroke={F} strokeWidth="2.2" strokeLinecap="round" d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M5.3 18.7l1.5-1.5M17.2 6.8l1.5-1.5" /></g>,
  'map.fill': () => <path fill={F} d="M3 6.5 8.5 4v14L3 20.5zM10 4l4.5 2v14L10 18zM16 6l5-2.5v14L16 20z" />,
  'pencil.and.outline': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M20 12.5a8.5 8.5 0 1 1-6-8.1" /><path d="M20.5 3.5l-9 9-.6 3 3-.6 9-9z" /></g>,
  'arrow.left.arrow.right': (w) => <path fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" d="M3 8h17m-4-4 4 4-4 4M21 16H4m4-4-4 4 4 4" />,
  'bubble.left.and.bubble.right.fill': () => <g fill={F}><path d="M9.5 4C5 4 1.5 6.8 1.5 10.3c0 1.6.8 3 2 4.1L3 17.5l3.2-1.7c1 .3 2.1.5 3.3.5 4.5 0 8-2.8 8-6.3S14 4 9.5 4z" /><path d="M19.8 19.5c1.3-.9 2.2-2.3 2.2-3.8 0-1.7-1-3.1-2.6-4 .1.4.1.8.1 1.2 0 4-3.5 7-8.1 7.4 1 .9 2.5 1.5 4.2 1.5.8 0 1.5-.1 2.2-.3l2.4 1.3z" /></g>,
  'clock.fill': () => <path fill={F} fillRule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm.8 4.5v5.2l3.6 2.1a.8.8 0 0 1-.8 1.4l-4-2.3a.8.8 0 0 1-.4-.7V6.5a.8.8 0 0 1 1.6 0z" />,
  calendar: () => GLYPHS['calendar.badge.clock'](2),
  'person.2.fill': () => <g fill={F}><circle cx="9" cy="8" r="3.6" /><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6z" /><circle cx="17.5" cy="9" r="2.8" /><path d="M16.6 14.2c3.2-.3 5.7 1.7 5.7 5.8h-5c0-2.2-.2-4-.7-5.8z" /></g>,
  'heart.fill': () => <path fill={F} d="M12 21s-8.5-5.2-8.5-11.2A4.8 4.8 0 0 1 12 7.2a4.8 4.8 0 0 1 8.5 2.6C20.5 15.8 12 21 12 21z" />,
  'moon.zzz.fill': (w) => <g><path fill={F} d="M19 15.5A8 8 0 0 1 8.5 5a8 8 0 1 0 10.5 10.5z" /><path fill="none" stroke={F} strokeWidth={w * 0.8} strokeLinecap="round" strokeLinejoin="round" d="M14.5 3.5h4l-4 4.5h4" /></g>,
  'slider.horizontal.3': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round"><path d="M3 6h8M17 6h4M3 12h3M12 12h9M3 18h10M19 18h2" /><circle cx="14" cy="6" r="2.2" /><circle cx="9" cy="12" r="2.2" /><circle cx="16" cy="18" r="2.2" /></g>,
  gearshape: (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinejoin="round"><path d="M19.4 10.2 L22.1 10.4 L22.1 13.6 L19.4 13.8 L18.5 15.9 L20.3 18.0 L18.0 20.3 L15.9 18.5 L13.8 19.4 L13.6 22.1 L10.4 22.1 L10.2 19.4 L8.1 18.5 L6.0 20.3 L3.7 18.0 L5.5 15.9 L4.6 13.8 L1.9 13.6 L1.9 10.4 L4.6 10.2 L5.5 8.1 L3.7 6.0 L6.0 3.7 L8.1 5.5 L10.2 4.6 L10.4 1.9 L13.6 1.9 L13.8 4.6 L15.9 5.5 L18.0 3.7 L20.3 6.0 L18.5 8.1z" /><circle cx="12" cy="12" r="3" /></g>,
  shield: (w) => <path fill="none" stroke={F} strokeWidth={w} strokeLinejoin="round" d="M12 3l7.5 2.8v5.7c0 4.7-3.2 8.5-7.5 10-4.3-1.5-7.5-5.3-7.5-10V5.8z" />,
  'square.and.pencil': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M11 4H6.5A2.5 2.5 0 0 0 4 6.5v11A2.5 2.5 0 0 0 6.5 20h11a2.5 2.5 0 0 0 2.5-2.5V13" /><path d="M18.5 3.5a1.9 1.9 0 0 1 2.7 2.7L12 15.4l-3.6 1 1-3.6z" /></g>,
  ellipsis: () => <g fill={F}><circle cx="5" cy="12" r="1.9" /><circle cx="12" cy="12" r="1.9" /><circle cx="19" cy="12" r="1.9" /></g>,
  magnifyingglass: (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round"><circle cx="10.5" cy="10.5" r="6.5" /><path d="M15.5 15.5L21 21" /></g>,
  'bookmark.fill': () => <path fill={F} d="M7 3h10a1 1 0 0 1 1 1v17l-6-4.5L6 21V4a1 1 0 0 1 1-1z" />,
  'text.bubble': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M5 4h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-7l-5 4v-4H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z" /><path d="M7.5 9h9M7.5 12.5h6" /></g>,
  'doc.text.fill': () => <path fill={F} fillRule="evenodd" d="M6 2h8l5 5v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm2 10v1.5h8V12zm0 3.5V17h8v-1.5zM8 8.5V10h4V8.5z" />,
  'arrow.triangle.2.circlepath': (w) => <path fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" d="M20 11a8 8 0 0 0-14.5-3.5M4 4v4h4M4 13a8 8 0 0 0 14.5 3.5M20 20v-4h-4" />,
  'point.3.connected.trianglepath.dotted': (w) => <g fill="none" stroke={F} strokeWidth={w * 0.8} strokeLinecap="round"><circle cx="12" cy="5.5" r="2.3" /><circle cx="5.5" cy="18" r="2.3" /><circle cx="18.5" cy="18" r="2.3" /><path d="M10.8 8 6.8 15.8M13.2 8l4 7.8M8.3 18h7.4" strokeDasharray="0.1 3" /></g>,
  'flag.fill': () => <path fill={F} d="M5 3a1 1 0 0 1 2 0v1h11l-2.5 4 2.5 4H7v8a1 1 0 0 1-2 0z" />,
  'envelope.open.badge.clock': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M3 10l9-6 9 6v8.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5zM3 10l9 6 9-6" /><circle cx="18.5" cy="18.5" r="3.6" fill={F} stroke="none" /></g>,
  'hand.raised.fill': () => <g fill={F}><rect x="5" y="10" width="14" height="11" rx="4.5" /><rect x="6" y="5.5" width="2.5" height="9" rx="1.250" /><rect x="9.5" y="3" width="2.5" height="10" rx="1.250" /><rect x="13" y="3.5" width="2.5" height="9.5" rx="1.250" /><rect x="16.5" y="6" width="2.5" height="8" rx="1.250" /></g>,
  'person.crop.circle.fill': () => <path fill={F} fillRule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4a3.2 3.2 0 1 1 0 6.4A3.2 3.2 0 0 1 12 6zm0 14.2a8 8 0 0 1-6-2.7c.1-2 4-3.1 6-3.1s5.9 1.1 6 3.1a8 8 0 0 1-6 2.7z" />,
  'square.and.arrow.up': (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M12 15V3.5M8 7.5l4-4 4 4M8 10.5H6.5A2.5 2.5 0 0 0 4 13v5.5A2.5 2.5 0 0 0 6.5 21h11a2.5 2.5 0 0 0 2.5-2.5V13a2.5 2.5 0 0 0-2.5-2.5H16" /></g>,
  square: (w) => <rect x="4" y="4" width="16" height="16" rx="3.5" fill="none" stroke={F} strokeWidth={w} />,
  sparkles: () => <g fill={F}><path d="M10 5l1.8 5.2L17 12l-5.2 1.8L10 19l-1.8-5.2L3 12l5.2-1.8z" /><path d="M18 2.5l.9 2.6 2.6.9-2.6.9L18 9.5l-.9-2.6-2.6-.9 2.6-.9zM18.5 14.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z" /></g>,
  'checkmark.circle.fill': () => <path fill={F} fillRule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm4.7 6.8a1 1 0 0 1 0 1.4l-5.3 5.3a1 1 0 0 1-1.4 0l-2.3-2.3a1 1 0 1 1 1.4-1.4l1.6 1.6 4.6-4.6a1 1 0 0 1 1.4 0z" />,
  checklist: (w) => <g fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M3 6.5l1.6 1.6L7.5 5M3 12.5l1.6 1.6 2.9-3.1M3 18.5l1.6 1.6 2.9-3.1M11 7h10M11 13h10M11 19h10" /></g>,
  'calendar.badge.checkmark': () => GLYPHS['calendar.badge.clock'](2),
  wind: (w) => <path fill="none" stroke={F} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" d="M3 9h10a2.5 2.5 0 1 0-2.5-2.5M3 14h14a2.5 2.5 0 1 1-2.5 2.5M3 19h7" />,
  'play.fill': () => <path fill={F} d="M8 4.8v14.4a1 1 0 0 0 1.5.9l11.6-7.2a1 1 0 0 0 0-1.8L9.5 3.9A1 1 0 0 0 8 4.8z" />,
  circle: (w) => <circle cx="12" cy="12" r="9.5" fill="none" stroke={F} strokeWidth={w} />,
};

export function Glyph({ name, size = 16, weight = 2, className = '' }: { name: string; size?: number; weight?: number; className?: string }) {
  const draw = GLYPHS[name] ?? GLYPHS['circle.hexagongrid.fill'];
  return (
    <svg className={`au-glyph ${className}`} width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      {draw(weight)}
    </svg>
  );
}

const TABS: [string, string][] = [['Now', 'sun.max.fill'], ['Plan', 'map.fill'], ['Journal', 'pencil.and.outline'], ['Bridge', 'arrow.left.arrow.right'], ['Thread', 'bubble.left.and.bubble.right.fill']];

/** The 440 x 956 pt Pro Max screen: status bar, help button, large title, scrolling cards 16 apart, floating tab bar. */
export type Toolbar = { leading?: string[]; trailing?: string[] };
const PLAIN_TOOLBAR = new Set(['ellipsis']);

function ToolbarGroup({ names, side }: { names: string[]; side: 'leading' | 'trailing' }) {
  if (names.length === 0) return null;
  return (
    <div className={`au-toolbar au-toolbar-${side}`}>
      {names.map((n) => (
        <button key={n} type="button" className={`au-toolbar-btn${PLAIN_TOOLBAR.has(n) ? ' au-toolbar-plain' : ''}`} aria-label={n === 'questionmark.circle' ? 'Help for this screen' : n === 'gearshape' ? 'Settings' : n === 'square.and.pencil' ? 'New entry' : 'More'}>
          <Glyph name={n} size={22} weight={1.8} />
        </button>
      ))}
    </div>
  );
}

/** The 440 x 956 pt Pro Max screen: status bar, toolbar buttons, large title, scrolling cards 16 apart, floating tab bar.
 *  With `pinned`, the title and that content stay fixed and only what follows scrolls (the Journal tab does this). */
export function AnchorScreen({ title, tab, onTab, toolbar = { trailing: ['questionmark.circle'] }, pinned, inset = 16, scheme = 'light', full = false, children }: { title: string; tab: string; onTab?: (tab: string) => void; toolbar?: Toolbar; pinned?: ReactNode; inset?: number; scheme?: 'light' | 'dark'; full?: boolean; children: ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const header = (
    <>
      <div className="au-nav-spacer" />
      <h1 className="au-nav-title">{title}</h1>
      {pinned}
    </>
  );
  return (
    <div className="au-screen" data-anchor-scheme={scheme} data-full={full ? '' : undefined} data-pinned={pinned && !full ? '' : undefined}>
      {pinned && !full ? (
        <div className="au-body">
          <div className="au-fixed">{header}</div>
          <div className="au-scroll au-scroll-below"><div className="au-stack" style={{ paddingTop: inset }}>{children}</div></div>
        </div>
      ) : (
        <div className="au-scroll" onScroll={(e) => setCollapsed(e.currentTarget.scrollTop > 40)}>
          {header}
          <div className="au-stack" style={{ paddingTop: inset }}>{children}</div>
        </div>
      )}
      {!(pinned && !full) && <div className="au-navbar" data-on={collapsed && !full ? '' : undefined}><span>{title}</span></div>}
      <div className="au-status">
        <span className="au-status-time">9:41</span>
        <span className="au-status-right">
          <svg width="22" height="14" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
          <svg width="21" height="15" viewBox="0 0 17 12" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M1.5 4.5a10 10 0 0 1 14 0M4 7.2a6.5 6.5 0 0 1 9 0" /><circle cx="8.5" cy="10" r="1" fill="currentColor" /></svg>
          <svg width="34" height="20" viewBox="0 0 27 18" className="au-battery"><g fill="none"><rect x="1" y="3" width="22" height="12" rx="3.5" stroke="currentColor" strokeOpacity=".4" /><rect x="3" y="5" width="18" height="8" rx="2" fill="#34c759" /></g></svg>
        </span>
      </div>
      <ToolbarGroup names={toolbar.leading ?? []} side="leading" />
      <ToolbarGroup names={toolbar.trailing ?? []} side="trailing" />
      <nav className="au-tabbar" aria-label="Tabs">
        {TABS.map(([name, icon]) => (
          <button key={name} type="button" className={`au-tab${name === tab ? ' au-tab-on' : ''}`} onClick={() => onTab?.(name)} aria-current={name === tab ? 'page' : undefined}>
            <Glyph name={icon} size={29} weight={1.9} />
            <span>{name}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}

/** Anchor.Card */
export function Card({ tint = 'accent', children }: { tint?: Tint; children: ReactNode }) {
  return <div className="au-card" style={tintStyle(tint)}>{children}</div>;
}

/** Anchor.SectionHeader */
export function SectionHeader({ icon, title, tint = 'accent' }: { icon: string; title: string; tint?: Tint }) {
  return (
    <div className="au-section-header" style={tintStyle(tint)}>
      <span className="au-badge au-badge-circle"><Glyph name={icon} size={18} /></span>
      <span className="au-headline">{title}</span>
    </div>
  );
}

/** Anchor.PrimaryButtonStyle */
export function PrimaryButton({ children, tint = 'accent', onClick }: { children: ReactNode; tint?: Tint; onClick?: () => void }) {
  return <button type="button" className="au-btn au-btn-primary" style={tintStyle(tint)} onClick={onClick}>{children}</button>;
}

/** Anchor.SecondaryButtonStyle */
export function SecondaryButton({ children, tint = 'accent', onClick }: { children: ReactNode; tint?: Tint; onClick?: () => void }) {
  return <button type="button" className="au-btn au-btn-secondary" style={tintStyle(tint)} onClick={onClick}>{children}</button>;
}

/** Anchor.MenuRow */
export function MenuRow({ icon, title, subtitle, tint = 'accent' }: { icon: string; title: string; subtitle?: string; tint?: Tint }) {
  return (
    <div className="au-menu-row" style={tintStyle(tint)}>
      <span className="au-badge au-badge-square"><Glyph name={icon} size={19} /></span>
      <span className="au-menu-text">
        <span className="au-body">{title}</span>
        {subtitle && <span className="au-caption au-secondary">{subtitle}</span>}
      </span>
    </div>
  );
}

/** Anchor.TileButtonLabel */
export function Tile({ icon, title, tint = 'accent', onClick }: { icon: string; title: string; tint?: Tint; onClick?: () => void }) {
  return (
    <button type="button" className="au-tile" style={tintStyle(tint)} onClick={onClick}>
      <span className="au-tile-icon"><Glyph name={icon} size={30} /></span>
      <span className="au-tile-title">{title}</span>
    </button>
  );
}

/** Anchor.TileRow */
export function TileRow({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="au-tile-row">
      <div className="au-subheadline au-semibold au-secondary au-pad-x">{title}</div>
      <div className="au-tile-scroll"><div className="au-tile-track">{children}</div></div>
    </div>
  );
}

/** Anchor.EmptyState */
export function EmptyState({ icon, title, message, actionTitle, tint = 'sage' }: { icon: string; title: string; message: string; actionTitle?: string; tint?: Tint }) {
  return (
    <Card tint={tint}>
      <div className="au-empty" style={tintStyle(tint)}>
        <span className="au-badge au-badge-circle au-badge-lg"><Glyph name={icon} size={28} /></span>
        <span className="au-headline">{title}</span>
        <span className="au-subheadline au-secondary au-center">{message}</span>
        {actionTitle && <SecondaryButton tint={tint}>{actionTitle}</SecondaryButton>}
      </div>
    </Card>
  );
}

/** CrisisNumbersView */
export function CrisisCard({ numbers, region }: { numbers: { label: string; display: string; kind: 'call' | 'text' }[]; region: string }) {
  return (
    <div className="au-crisis">
      <div className="au-headline au-crisis-title"><Glyph name="cross.case.fill" size={21} />Crisis numbers</div>
      {numbers.map((n) => (
        <div key={n.label} className="au-crisis-row">
          <span className="au-subheadline au-medium">{n.label}</span>
          <span className="au-crisis-num">{n.display}<Glyph name={n.kind === 'call' ? 'phone.fill' : 'message.fill'} size={21} /></span>
        </div>
      ))}
      <div className="au-caption au-crisis-foot"><Glyph name="globe" size={13} weight={1.8} />Numbers for {region}. Change</div>
    </div>
  );
}

/** MascotPresenceView, MascotCharacterView and SpeechBubble */
export function MascotPresence({ line }: { line: string }) {
  return (
    <div className="au-mascot-row">
      <div className="au-mascot"><span className="au-eyes"><i /><i /></span></div>
      <div className="au-bubble"><span className="au-callout">{line}</span></div>
    </div>
  );
}

/** A contact chip from QuickContactsView */
export function ContactChip({ name, selected, onClick }: { name: string; selected: boolean; onClick?: () => void }) {
  return (
    <button type="button" className={`au-chip${selected ? ' au-chip-on' : ''}`} onClick={onClick}>
      <span className="au-chip-initial">{name.slice(0, 1)}</span>
      <span className="au-subheadline au-semibold">{name}</span>
    </button>
  );
}

/** SafetyPlanShortcutView */
export function ShortcutRow({ icon, title }: { icon: string; title: string }) {
  return (
    <Card>
      <div className="au-shortcut">
        <span className="au-badge au-badge-circle au-badge-md"><Glyph name={icon} size={19} /></span>
        <span className="au-subheadline au-medium au-grow">{title}</span>
        <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
      </div>
    </Card>
  );
}

/** GroundingToolRow */
export function ToolRow({ title, icon = 'list.number' }: { title: string; icon?: string }) {
  return (
    <button type="button" className="au-tool-row" style={tintStyle('sage')}>
      <span className="au-tool-icon"><Glyph name={icon} size={20} weight={2} /></span>
      <span className="au-subheadline au-grow">{title}</span>
      <span className="au-tertiary"><Glyph name="chevron.right" size={19} weight={2.6} /></span>
    </button>
  );
}


/** A thin separator, like SwiftUI's Divider. */
export function Divider() { return <div className="au-divider" role="separator" />; }

/** A horizontally scrolling row with no scroll bar, like ScrollView(.horizontal, showsIndicators: false). */
export function HScroll({ children }: { children: ReactNode }) {
  return <div className="au-hscroll"><div className="au-hscroll-track">{children}</div></div>;
}

/** RecoveryNowCard counter row */
export function RecoveryRow({ name, line, number, label }: { name: string; line: string; number: string; label: string }) {
  return (
    <div className="au-recovery-row">
      <div className="au-recovery-text"><span className="au-headline">{name}</span><span className="au-caption au-secondary">{line}</span></div>
      <div className="au-recovery-num"><span className="au-recovery-big">{number}</span><span className="au-caption au-secondary">{label}</span></div>
      <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
    </div>
  );
}

/** DecisionPresetsQuickView chips */
export function PresetChip({ category, name }: { category: string; name: string }) {
  return <button type="button" className="au-preset"><span className="au-caption2 au-secondary">{category}</span><span className="au-subheadline au-medium">{name}</span></button>;
}
export function RoutineChip({ name }: { name: string }) {
  return <button type="button" className="au-preset au-preset-row"><Glyph name="play.fill" size={14} /><span className="au-subheadline au-medium">{name}</span></button>;
}

/** The soft box used by DeEscalationCardView and AffirmationsCardView */
export function QuoteBox({ tint = 'accent', italic = false, children }: { tint?: Tint; italic?: boolean; children: ReactNode }) {
  return <div className={`au-quote${italic ? ' au-italic' : ''}`} style={{ background: `var(--anchor-${tint}-soft)` }}>{children}</div>;
}

/** A task row from TasksNowCard */
export function TaskRow({ title, onDone }: { title: string; onDone?: () => void }) {
  return (
    <div className="au-task">
      <button type="button" className="au-task-check" aria-label={`Mark ${title} as done`} onClick={onDone}><Glyph name="circle" size={22} weight={1.6} /></button>
      <span className="au-subheadline">{title}</span>
    </div>
  );
}

/** Anchor.Widget: a card with an icon badge, a title, a chevron, then content and an optional footer. */
export function Widget({ icon, title, tint = 'accent', children, footer }: { icon: string; title: string; tint?: Tint; children?: ReactNode; footer?: ReactNode }) {
  return (
    <Card tint={tint}>
      <div className="au-widget" style={tintStyle(tint)}>
        <div className="au-widget-main">
          <div className="au-widget-head">
            <span className="au-badge au-badge-circle au-badge-sm"><Glyph name={icon} size={15} /></span>
            <span className="au-subheadline au-semibold au-widget-title">{title}</span>
            <span className="au-tertiary"><Glyph name="chevron.right" size={18} weight={2.8} /></span>
          </div>
          {children}
        </div>
        {footer}
      </div>
    </Card>
  );
}
export function WidgetBig({ text }: { text: string }) { return <div className="au-widget-big">{text}</div>; }
export function WidgetCaption({ text, lines = 3 }: { text: string; lines?: number }) { return <div className="au-caption au-secondary au-clamp" style={{ WebkitLineClamp: lines }}>{text}</div>; }
export function WidgetPair({ left, right }: { left: ReactNode; right: ReactNode }) { return <div className="au-pair"><div>{left}</div><div>{right}</div></div>; }

/** The "More" row and "Customise" button at the end of a widget tab (WidgetStack). */
export function WidgetFooter({ tucked }: { tucked: { id: string; icon: string; title: string; tint: Tint }[] }) {
  return (
    <>
      {tucked.length > 0 && (
        <div className="au-more">
          <div className="au-subheadline au-semibold au-secondary">More</div>
          <div className="au-tile-scroll au-more-scroll"><div className="au-tile-track au-more-track">{tucked.map((t) => <Tile key={t.id} icon={t.icon} title={t.title} tint={t.tint} />)}</div></div>
        </div>
      )}
      <button type="button" className="au-customise"><Glyph name="slider.horizontal.3" size={17} weight={1.8} />Customise</button>
    </>
  );
}

/** A search field like the one .searchable puts under the large title. */
export function SearchField({ value, onChange, prompt }: { value: string; onChange: (v: string) => void; prompt: string }) {
  return (
    <label className="au-search">
      <Glyph name="magnifyingglass" size={19} weight={2.2} />
      <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={prompt} aria-label={prompt} />
    </label>
  );
}

/** Picker(...).pickerStyle(.segmented) */
export function Segmented({ options, value, onChange }: { options: string[]; value: string; onChange: (v: string) => void }) {
  return (
    <div className="au-segmented" role="tablist">
      {options.map((o) => <button key={o} type="button" role="tab" aria-selected={o === value} className={o === value ? 'au-seg-on' : ''} onClick={() => onChange(o)}>{o}</button>)}
    </div>
  );
}

/** Journal timeline pieces */
export function DayMarker({ day, month }: { day: string; month: string }) {
  return (
    <div className="au-day">
      <span className="au-day-badge"><b>{day}</b><i>{month}</i></span>
      <span className="au-day-line" />
    </div>
  );
}
export function TimelineRow({ checkIn = false, children }: { checkIn?: boolean; children: ReactNode }) {
  return (
    <div className="au-tl-row">
      <span className="au-tl-conn"><span className="au-tl-dot" />{!checkIn && <span className="au-tl-stub" />}</span>
      <div className="au-tl-body">{children}</div>
    </div>
  );
}
export function EntryCard({ time, bookmarked, preview, chips }: { time: string; bookmarked: boolean; preview: string | null; chips: string[] }) {
  return (
    <button type="button" className="au-entry">
      <span className="au-entry-top"><span className="au-caption2 au-secondary">{time}</span>{bookmarked && <span className="au-accent"><Glyph name="bookmark.fill" size={12} /></span>}</span>
      <span className={`au-subheadline au-clamp2${preview ? '' : ' au-secondary'}`}>{preview ?? 'Empty entry'}</span>
      {chips.length > 0 && <span className="au-chips-row">{chips.map((c) => <span key={c} className="au-tag au-caption2 au-secondary">{c}</span>)}</span>}
    </button>
  );
}
export function CheckInRowCard({ time, answered, readings }: { time: string; answered: boolean; readings: { short: string; value: number }[] }) {
  return (
    <button type="button" className="au-checkin">
      <span className="au-checkin-top">
        <span className="au-caption2 au-secondary">{time}</span>
        <span className="au-caption au-medium au-accent">Check-in</span>
        {answered && <span className="au-secondary au-inline"><Glyph name="text.bubble" size={12} weight={2} /></span>}
        <span className="au-secondary au-inline"><Glyph name="chevron.right" size={18} weight={2.8} /></span>
      </span>
      <span className="au-readings">
        {readings.map((r) => (
          <span key={r.short} className="au-reading"><span className="au-caption2 au-secondary">{r.short}</span><span className="au-bar"><span style={{ width: `${r.value * 100}%` }} /></span></span>
        ))}
      </span>
    </button>
  );
}

/** One of the "things to raise" rows: an outlined square and the text. */
export function RaiseRow({ text, onToggle }: { text: string; onToggle: () => void }) {
  return (
    <button type="button" className="au-raise" onClick={onToggle}>
      <span className="au-accent au-raise-box"><Glyph name="square" size={24} weight={1.5} /></span>
      <span className="au-subheadline au-clamp2">{text}</span>
    </button>
  );
}

/** The week strip in SupportCalendarWidget */
export function WeekStrip({ days }: { days: { narrow: string; day: number; today: boolean; hasEntry: boolean }[] }) {
  return (
    <div className="au-week">
      {days.map((d) => (
        <div key={d.narrow} className="au-week-day">
          <span className="au-caption2 au-secondary">{d.narrow}</span>
          <span className={`au-week-num au-caption${d.today ? ' au-week-today' : ''}`}>{d.day}</span>
          <span className={`au-week-dot${d.hasEntry ? ' au-week-dot-on' : ''}`} />
        </div>
      ))}
    </div>
  );
}
