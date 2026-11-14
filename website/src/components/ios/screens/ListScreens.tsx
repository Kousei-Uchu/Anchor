import type { ReactNode } from 'react';
import { Card, Glyph, ListCard, SecondaryButton } from '../AnchorUI';
import { affirmations, contactRows, deEscalationScripts, groundingToolRows } from '../../../content/seed';

/** Pushed list screens. Each hook returns what the shell needs: the title, the toolbar, and the body. */
export type DetailParts = { title: string; toolbar: { trailing: string[] }; inset: number; body: ReactNode };
const REORDER_ADD = ['questionmark.circle', 'text:Reorder', 'plus'];

/** ContactsEditorView */
export function useContacts(): DetailParts {
  return {
    title: 'Contacts', toolbar: { trailing: REORDER_ADD }, inset: 18,
    body: (
      <>
        <Card>
          <div className="au-listcard">
            <span className="au-badge au-badge-square" style={{ ['--tint' as string]: 'var(--anchor-sage)' }}><Glyph name="sunrise" size={19} /></span>
            <div className="au-listcard-main" style={{ gap: 2 }}>
              <span className="au-body au-medium">Who's awake right now</span>
              <span className="au-caption au-secondary">Local times for people in other timezones</span>
            </div>
            <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
          </div>
        </Card>
        {contactRows().map((c) => (
          <Card key={c.name}>
            <div className="au-listcard-main">
              <div className="au-row-top">
                <span className="au-headline au-grow">{c.name}</span>
                {c.onNow && <span className="au-caption au-label-sage"><Glyph name="bolt.fill" size={22} />On Now</span>}
                <span className="au-tertiary"><Glyph name="chevron.right" size={20} weight={2.8} /></span>
              </div>
              <span className="au-subheadline au-secondary">{c.phone}</span>
            </div>
          </Card>
        ))}
      </>
    ),
  };
}

/** GroundingToolsEditorView */
export function useGrounding(): DetailParts {
  return {
    title: 'Grounding tools', toolbar: { trailing: REORDER_ADD }, inset: 18,
    body: (
      <>
        {groundingToolRows().map((t) => (
          <ListCard key={t.title} tint="sage" accessory={t.hasSteps ? <span className="au-play"><Glyph name="play.circle.fill" size={32} /></span> : undefined}>
            <div className="au-row-top">
              <span className="au-headline au-grow">{t.title}</span>
              <span className="au-caption au-secondary au-label-plain"><Glyph name={t.kindLabel === 'Steps' ? 'list.number' : 'play.fill'} size={18} />{t.kindLabel}</span>
            </div>
            <span className="au-subheadline au-secondary">{t.when}</span>
          </ListCard>
        ))}
      </>
    ),
  };
}

/** The de-escalation scripts editor */
export function useDeEscalation(): DetailParts {
  return {
    title: 'De-escalation scripts', toolbar: { trailing: REORDER_ADD }, inset: 18,
    body: <>{deEscalationScripts().map((t) => <Card key={t}><div className="au-rowtext">{'\u201C'}{t}{'\u201D'}</div></Card>)}</>,
  };
}

/** The affirmations editor */
export function useAffirmations(): DetailParts {
  return {
    title: 'Affirmations', toolbar: { trailing: REORDER_ADD }, inset: 18,
    body: (
      <>
        {affirmations().map((t) => <Card key={t}><div className="au-rowtext">{t}</div></Card>)}
        <div className="au-center-row"><SecondaryButton><Glyph name="book.fill" size={22} />Browse suggestions</SecondaryButton></div>
      </>
    ),
  };
}
