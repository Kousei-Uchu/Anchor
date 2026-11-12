import { useEffect } from 'react';
import { MotionConfig } from 'motion/react';
import { Route, Routes, useLocation } from 'react-router-dom';
import { IconSprite } from './components/Icons';
import { Header } from './components/Header';
import { Footer } from './components/Footer';
import Home from './pages/Home';
import Demo from './pages/Demo';
import About from './pages/About';
import Beta from './pages/Beta';
import Features from './pages/Features';
import Philosophy from './pages/Philosophy';
import Privacy from './pages/Privacy';
import Support from './pages/Support';
import NotFound from './pages/NotFound';
import DemoNow from './pages/DemoNow';

/** New page → top. Page with a #hash → that section (the browser can't, since React renders after navigation). */
function ScrollManager() {
  const { pathname, hash } = useLocation();
  useEffect(() => {
    const calm = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (hash) {
      const go = () => document.getElementById(decodeURIComponent(hash.slice(1)))?.scrollIntoView({ behavior: calm ? 'auto' : 'smooth', block: 'start' });
      const id = requestAnimationFrame(go);
      return () => cancelAnimationFrame(id);
    }
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  }, [pathname, hash]);
  return null;
}

export function App() {
  return (
    <MotionConfig reducedMotion="user">
      <IconSprite />
      <a className="skip-link" href="#main">Skip to content</a>
      <ScrollManager />
      <Header />
      <div id="main">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/about" element={<About />} />
          <Route path="/beta" element={<Beta />} />
          <Route path="/features" element={<Features />} />
          <Route path="/philosophy" element={<Philosophy />} />
          <Route path="/demo" element={<Demo />} />
          <Route path="/privacy" element={<Privacy />} />
          <Route path="/support" element={<Support />} />
          {import.meta.env.DEV && <Route path="/demo-now" element={<DemoNow />} />}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </div>
      <Footer />
    </MotionConfig>
  );
}
