import { useState, type ReactNode } from 'react';
import '@fontsource-variable/nunito';
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
  'battery.100': () => <g fill="none"><rect x="1" y="3" width="22" height="12" rx="3.5" stroke={F} strokeOpacity=".4" /><rect x="3" y="5" width="18" height="8" rx="2" fill={F} /><path d="M25 7v4" stroke={F} strokeOpacity=".4" strokeLinecap="round" /></g>,
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
export function AnchorScreen({ title, tab, scheme = 'light', children }: { title: string; tab: string; scheme?: 'light' | 'dark'; children: ReactNode }) {
  return (
    <div className="au-screen" data-anchor-scheme={scheme}>
      <div className="au-scroll">
        <div className="au-nav-spacer" />
        <h1 className="au-nav-title">{title}</h1>
        <div className="au-stack">{children}</div>
      </div>
      <div className="au-status">
        <span className="au-status-time">9:41</span>
        <span className="au-status-right">
          <svg width="22" height="14" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
          <svg width="21" height="15" viewBox="0 0 17 12" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M1.5 4.5a10 10 0 0 1 14 0M4 7.2a6.5 6.5 0 0 1 9 0" /><circle cx="8.5" cy="10" r="1" fill="currentColor" /></svg>
          <svg width="34" height="20" viewBox="0 0 27 18" className="au-battery"><g fill="none"><rect x="1" y="3" width="22" height="12" rx="3.5" stroke="currentColor" strokeOpacity=".4" /><rect x="3" y="5" width="18" height="8" rx="2" fill="#34c759" /></g></svg>
        </span>
      </div>
      <button type="button" className="au-help" aria-label="Help for this screen"><Glyph name="questionmark.circle" size={22} weight={1.8} /></button>
      <nav className="au-tabbar" aria-label="Tabs">
        {TABS.map(([name, icon]) => (
          <span key={name} className={`au-tab${name === tab ? ' au-tab-on' : ''}`}>
            <Glyph name={icon} size={29} weight={1.9} />
            <span>{name}</span>
          </span>
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
        <span className="au-tertiary"><Glyph name="chevron.right" size={12} weight={2.8} /></span>
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
      <span className="au-tertiary"><Glyph name="chevron.right" size={11} weight={2.6} /></span>
    </button>
  );
}

/** Convenience for pages that need a selectable list of chips. */
export function useChoice<T>(first: T) { return useState<T>(first); }
