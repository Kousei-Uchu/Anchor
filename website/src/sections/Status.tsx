import { Link } from 'react-router-dom';
import { Reveal } from '../components/Reveal';
import { Icon } from '../components/Icons';
import { Mascot } from '../components/Mascot';

export function Status() {
  return (
    <section className="section" id="status">
      <Reveal className="status-card">
        <span className="note-ic"><Icon name="anc" className="ic anchor" /></span>
        <h2>Anchor is not finished.</h2>
        <p>
          <strong>This is an early build.</strong> Screens, features and wording may change, things may break, and what you see here may not match the app yet.
        </p>
        <h3>The one thing that won&rsquo;t change</h3>
        <ul className="promises">
          <li><Icon name="check" /><span>Anchor sends <strong>no data</strong> anywhere. Everything you write stays on your device.</span></li>
          <li><Icon name="check" /><span>If a future feature ever truly needs to send something, it will be the <strong>minimum necessary</strong>.</span></li>
          <li><Icon name="check" /><span>If that ever changes, you will be <strong>told immediately, in the app</strong>, before anything is sent.</span></li>
        </ul>
        <p className="after">Read the full <Link to="/privacy">privacy policy</Link>.</p>
        <div className="status-mascot" aria-hidden="true"><Mascot size={148} /></div>
      </Reveal>
    </section>
  );
}
