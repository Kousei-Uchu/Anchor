import { Link } from 'react-router-dom';
import { DemoApp } from '../components/DemoApp';
import { DEVICE_H, DEVICE_W, PhoneFrame } from '../components/PhoneFrame';
import { Reveal } from '../components/Reveal';
import { useViewportSize } from '../hooks/useViewportSize';

const TIPS = [
  ['Check in', ' on the Now tab, then skip any question you like.'],
  ['Grounding tools', ': try 5-4-3-2-1 or Cold water.'],
  ['The + in Journal', ' adds an entry. It stays on this page only.'],
  ['The tabs along the bottom', ' show Plan, Journal, Bridge and Thread.'],
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
            <DemoApp />
          </PhoneFrame>
        </Reveal>
      </div>
    </section>
  );
}
