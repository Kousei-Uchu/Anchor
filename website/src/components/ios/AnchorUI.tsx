import type { ReactNode } from 'react';
import '../../styles/design.generated.css';
import './anchor-ui.css';

/** Mirrors Anchor.Theme tints. The colours themselves come from design.generated.css. */
export type Tint = 'accent' | 'sage';
const tintStyle = (tint: Tint) => ({ ['--tint' as string]: `var(--anchor-${tint})` });

/** Small line icons drawn for the website. SF Symbols cannot be used off Apple platforms, so these stand in for them. */
const GLYPHS: Record<string, ReactNode> = {
  chevron: <path d="M9 6l6 6-6 6" />,
  calendar: (<><rect x="4" y="5.5" width="16" height="14" rx="3" /><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4" /></>),
  hex: <path d="M12 3l7.8 4.5v9L12 21l-7.8-4.5v-9z" />,
  leaf: <path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14M5 19c2-4 5-7 9-9" />,
  heart: <path d="M12 20s-7.5-4.6-7.5-10A4.2 4.2 0 0 1 12 7.6 4.2 4.2 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z" />,
  wind: <path d="M3 9h10a2.5 2.5 0 1 0-2.5-2.5M3 14h14a2.5 2.5 0 1 1-2.5 2.5M3 19h7" />,
  hand: <path d="M8 12V6.5a1.5 1.5 0 0 1 3 0V11m0-5.5a1.5 1.5 0 0 1 3 0V11m0-3a1.5 1.5 0 0 1 3 0v6c0 4-2.5 6-5.5 6S7 18 6 15l-1.2-3a1.4 1.4 0 0 1 2.4-1.4z" />,
  eye: (<><path d="M2.5 12S6 6 12 6s9.5 6 9.5 6-3.5 6-9.5 6S2.5 12 2.5 12z" /><circle cx="12" cy="12" r="2.5" /></>),
  check: <path d="M5 12.5l4.5 4.5L19 7.5" />,
};

export function Glyph({ name, size = 16, weight = 2 }: { name: string; size?: number; weight?: number }) {
  return (
    <svg className="au-glyph" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={weight} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {GLYPHS[name] ?? GLYPHS.hex}
    </svg>
  );
}

/** A screen the way the app lays one out: warm background, large title, cards 16 apart with 16 around. */
export function AnchorScreen({ title, scheme = 'light', children }: { title: string; scheme?: 'light' | 'dark'; children: ReactNode }) {
  return (
    <div className="au-screen" data-anchor-scheme={scheme}>
      <div className="au-scroll">
        <h1 className="au-nav-title">{title}</h1>
        <div className="au-stack">{children}</div>
      </div>
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
      <span className="au-badge au-badge-circle"><Glyph name={icon} size={14} weight={2.4} /></span>
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
      <span className="au-badge au-badge-square"><Glyph name={icon} size={15} weight={2.4} /></span>
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
      <span className="au-tile-icon"><Glyph name={icon} size={24} weight={2.1} /></span>
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
        <span className="au-badge au-badge-circle au-badge-lg"><Glyph name={icon} size={22} weight={2.1} /></span>
        <span className="au-headline">{title}</span>
        <span className="au-subheadline au-secondary au-center">{message}</span>
        {actionTitle && <SecondaryButton tint={tint}>{actionTitle}</SecondaryButton>}
      </div>
    </Card>
  );
}
