import { useState } from 'react';
import { Card, MascotPresence, PrimaryButton, RangeSlider, SecondaryButton, SectionHeader } from '../AnchorUI';

/**
 * CheckInSliderView: the check-in sheet. Five sliders (more is better on all of them), a button for the optional questions, and Finish.
 * The mascot line is the one MascotEngine gives for a check-in prompt in the gentle mood. Nothing is saved on the website.
 */
const SLIDERS = [
  { title: 'Physical energy', icon: 'bolt.fill', low: 'running on empty', high: 'fully charged' },
  { title: 'Mental clarity', icon: 'lightbulb.fill', low: 'foggy', high: 'clear' },
  { title: 'Room in your head', icon: 'cloud.fill', low: 'crowded', high: 'plenty of space' },
  { title: 'Physical energy to move', icon: 'figure.walk', low: 'hard to move', high: 'ready to move' },
  { title: 'Social energy', icon: 'person.2.fill', low: 'need space', high: 'up for company' },
];

export default function CheckInSheet({ scheme, onClose }: { scheme: 'light' | 'dark'; onClose: () => void }) {
  const [values, setValues] = useState<number[]>(SLIDERS.map(() => 0.5));
  return (
    <div className="au-sheet-wrap" data-anchor-scheme={scheme}>
      <div className="au-sheet-dim" />
      <div className="au-sheet" data-anchor-scheme={scheme} role="dialog" aria-label="Check in">
        <div className="au-sheet-scroll">
          <button type="button" className="au-skip" onClick={onClose}>Skip</button>
          <h1 className="au-sheet-title">Check in</h1>
          <div className="au-sheet-stack">
            <MascotPresence line="Want to check in? Totally fine to skip." tone="sage" />
            {SLIDERS.map((sl, i) => (
              <Card key={sl.title}>
                <div className="au-stack-8">
                  <SectionHeader icon={sl.icon} title={sl.title} />
                  <RangeSlider label={sl.title} value={values[i]} onChange={(v) => setValues((all) => all.map((x, j) => (j === i ? v : x)))} />
                  <div className="au-slider-ends"><span>{sl.low}</span><span>{sl.high}</span></div>
                </div>
              </Card>
            ))}
            <div className="au-footnote">More = better, across all five. Just for you, nothing here is scored, averaged, or shown as a streak.</div>
          </div>
        </div>
        <div className="au-sheet-bar">
          <SecondaryButton>A few optional questions</SecondaryButton>
          <PrimaryButton onClick={onClose}>Finish</PrimaryButton>
          <div className="au-caption au-secondary">Finishing here is complete. The questions are extra, not required.</div>
        </div>
      </div>
    </div>
  );
}
