import { Link } from 'react-router-dom';
import { DemoPhone } from '../components/DemoPhone';
import { DEVICE_H, DEVICE_W, PhoneFrame } from '../components/PhoneFrame';
import { Reveal } from '../components/Reveal';
import { useViewportSize } from '../hooks/useViewportSize';

const TIPS = [
  ['Tap anything that looks tappable', ' to open it, like the cards in Plan or the Check in button on Now.'],
  ['Back', ' goes to the screen before. Tap the tab you are on to return to its first screen.'],
  ['Scroll', ' inside the phone with the wheel or a swipe.'],
  ['The tabs along the bottom', ' show Now, Plan, Journal, Bridge and Thread.'],
];

export function TryDemo() {
  const { w, h } = useViewportSize();
  const scale = Math.max(0.5, Math.min(0.92, (w - 40) / DEVICE_W, (h - 120) / DEVICE_H));
  return (
    <section className="section" id="demo">
      <div className="demo-grid">
        <Reveal className="demo-copy">
          <p className="eyebrow">Hands on</p>
          <h2>Try it here</h2>
          <p className="lead">A tappable demo with made-up content. Nothing you type is saved or sent.</p>
          <ul className="tips">
            {TIPS.map(([a, b]) => (
              <li key={a}><strong>{a}</strong>{b}</li>
            ))}
          </ul>
          <p><Link className="button ghost" to="/demo">Open full screen</Link></p>
        </Reveal>
        <Reveal className="demo-phone">
          <PhoneFrame scale={scale}>
            <DemoPhone />
          </PhoneFrame>
        </Reveal>
      </div>
    </section>
  );
}
