import { Card, CrisisCard, Glyph, MascotPresence, PrimaryButton, ShortcutRow } from '../AnchorUI';
import { Affirmations, DecisionPresetsCard, DeEscalation, GroundingTools, NextAppointmentCard, QuickContacts, RecoveryNowCard, TasksNow } from '../cards';
import demo from '../../../content/demo.generated.json';

/**
 * The Now tab, in the order NowView.swift lays it out. The Sleep card is left out because the app only shows it when its setting is on,
 * and the demo does not turn it on. The crisis numbers are the Australian set the demo uses.
 */
const NUMBERS = [
  { label: 'Emergency', display: '000', kind: 'call' as const },
  { label: 'Lifeline (call)', display: '13 11 14', kind: 'call' as const },
  { label: 'Lifeline (text)', display: '0477 13 11 14', kind: 'text' as const },
];

export default function NowTab() {
  return (
    <>
      <CrisisCard numbers={NUMBERS} region="Australia" />
      <MascotPresence line={demo.mascot.hello} />
      <PrimaryButton><Glyph name="circle.hexagongrid.fill" size={22} />Check in</PrimaryButton>
      <Card><QuickContacts /></Card>
      <RecoveryNowCard />
      <NextAppointmentCard />
      <ShortcutRow icon="shield.fill" title="Open my safety plan" />
      <DecisionPresetsCard />
      <Card tint="sage"><GroundingTools /></Card>
      <Card><TasksNow /></Card>
      <Card tint="sage"><DeEscalation /></Card>
      <Card><Affirmations /></Card>
    </>
  );
}
