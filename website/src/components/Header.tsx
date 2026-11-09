import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { GITHUB_URL } from '../content/meta';
import { Icon } from './Icons';

export function Header() {
  const [open, setOpen] = useState(false);
  const { pathname, hash } = useLocation();
  useEffect(() => setOpen(false), [pathname, hash]);

  return (
    <header className={`hdr${open ? ' open' : ''}`}>
      <Link className="brand" to="/" onClick={() => setOpen(false)}>
        <img src="/assets/icon.png" alt="" width="28" height="28" />
        Anchor
      </Link>
      <button type="button" className="menu-btn" aria-label={open ? 'Close menu' : 'Open menu'} aria-expanded={open} aria-controls="site-nav" onClick={() => setOpen((o) => !o)}>
        <Icon name={open ? 'close' : 'menu'} />
      </button>
      <nav id="site-nav" aria-label="Main">
        <Link to="/features">Features</Link>
        <Link to="/philosophy">Philosophy</Link>
        <Link to="/demo">Demo</Link>
        <Link to={{ pathname: '/', hash: '#about' }}>About</Link>
        <Link to="/privacy">Privacy</Link>
        <Link to="/support">Support</Link>
        <a href={GITHUB_URL}>GitHub</a>
        <Link className="pill" to={{ pathname: '/', hash: '#status' }}>Early build</Link>
      </nav>
    </header>
  );
}
