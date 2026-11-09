import { Link } from 'react-router-dom';
import { GITHUB_URL } from '../content/meta';

export function Footer() {
  return (
    <footer className="ft">
      <nav aria-label="Footer">
        <Link to="/features">Features</Link>
        <Link to="/philosophy">Philosophy</Link>
        <Link to="/privacy">Privacy</Link>
        <Link to="/support">Support</Link>
        <Link to="/demo">Demo</Link>
        <a href={GITHUB_URL}>GitHub</a>
      </nav>
      <p>Anchor is a personal support tool. It is not a medical device and not an emergency service. If you are in danger, call your local emergency number.</p>
    </footer>
  );
}
