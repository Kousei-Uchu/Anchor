import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion, useMotionValueEvent, useReducedMotion, useScroll, useSpring, useTransform } from 'motion/react';
import { SLIDES } from '../content/story';
import { DemoApp } from '../components/DemoApp';
import { DEVICE_H, DEVICE_W, PhoneFrame } from '../components/PhoneFrame';
import { Mascot } from '../components/Mascot';
import { Icon } from '../components/Icons';
import { useViewportSize } from '../hooks/useViewportSize';

const N = SLIDES.length;
/** Scroll positions where each step is centred, plus the two ends, for smooth scroll-linked motion. */
const STOPS = [0, ...SLIDES.map((_, i) => (i + 0.5) / N), 1];
const ext = <T,>(v: T[]) => [v[0], ...v, v[v.length - 1]];

/**
 * The intro. A tall section holds a pinned (position: sticky) stage; the page scrolls normally
 * and the stage reads how far through the section you are. Nothing intercepts wheel, touch or keys,
 * so trackpads, scrollbars, keyboards, anchor links and the back button all behave.
 */
export function HeroStory() {
  const ref = useRef<HTMLElement>(null);
  const [step, setStep] = useState(0);
  const reduce = useReducedMotion();
  const { w, h } = useViewportSize();
  const copyRef = useRef<HTMLDivElement>(null);
  const [copyH, setCopyH] = useState(300);
  useEffect(() => {
    const el = copyRef.current;
    if (!el || !('ResizeObserver' in window)) return;
    const ro = new ResizeObserver(() => setCopyH(el.offsetHeight));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end end'] });
  const smooth = useSpring(scrollYProgress, { stiffness: 80, damping: 24, restDelta: 0.0004 });

  useMotionValueEvent(scrollYProgress, 'change', (p) => {
    const raw = p * N;
    setStep((prev) => {
      const next = Math.min(N - 1, Math.max(0, Math.floor(raw)));
      // a small dead zone at each boundary, so resting right on a line doesn't flicker
      if (next !== prev && Math.abs(raw - (prev + 0.5)) < 0.5 + 0.03) return prev;
      return next;
    });
  });

  const tilt = useTransform(smooth, STOPS, ext(SLIDES.map((s) => s.tilt)));
  const lift = useTransform(smooth, STOPS, ext(SLIDES.map((s) => s.lift ?? 0)));
  const g1x = useTransform(smooth, STOPS, ext(SLIDES.map((s) => `${s.glow[0]}vmax`)));
  const g1y = useTransform(smooth, STOPS, ext(SLIDES.map((s) => `${s.glow[1]}vmax`)));
  const g2x = useTransform(smooth, STOPS, ext(SLIDES.map((s) => `${s.glow[2]}vmax`)));
  const g2y = useTransform(smooth, STOPS, ext(SLIDES.map((s) => `${s.glow[3]}vmax`)));

  const narrow = w <= 800;
  const room = narrow ? h - 60 - 54 - copyH - 12 : h - 120;
  const scale = Math.max(0.34, Math.min(room / DEVICE_H, (narrow ? w * 0.92 : w * 0.4) / DEVICE_W, narrow ? 0.62 : 0.8));

  const goTo = (i: number) => {
    const el = ref.current;
    if (!el) return;
    const top = el.getBoundingClientRect().top + window.scrollY;
    const length = el.offsetHeight - window.innerHeight;
    window.scrollTo({ top: top + ((i + 0.5) / N) * length, behavior: reduce ? 'auto' : 'smooth' });
  };

  const s = SLIDES[step];
  return (
    <section ref={ref} className="story" style={{ ['--n' as string]: N }} aria-label="Anchor intro">
      <div className="pin" data-step={step}>
        <motion.div className="glow g1" style={reduce ? undefined : { x: g1x, y: g1y }} aria-hidden="true" />
        <motion.div className="glow g2" style={reduce ? undefined : { x: g2x, y: g2y }} aria-hidden="true" />

        <div className="story-grid">
          <div className="copy" ref={copyRef}>
            {SLIDES.map((sl, i) => (
              <div key={sl.title} className={`slide ${i < step ? 'past' : i > step ? 'next' : 'on'}`} inert={i !== step}>
                {i === 0 && (
                  <div className="hero-mascot">
                    <Mascot size={112} />
                  </div>
                )}
                {sl.tag && <span className="tag">{sl.tag}</span>}
                {i === 0 ? <h1>{sl.title}</h1> : <h2>{sl.title}</h2>}
                <p>{sl.body}</p>
                {i === 0 && (
                  <div className="btns">
                    <Link className="button" to="/demo">Try the demo</Link>
                    <a className="button ghost" href="#status">Early build, read this</a>
                  </div>
                )}
                {i === N - 1 && (
                  <div className="btns">
                    <a className="button" href="#status">What that means</a>
                    <a className="button ghost" href="#about">Explore Anchor</a>
                  </div>
                )}
              </div>
            ))}
          </div>

          <div className="phone-col" aria-hidden="true">
            <div className="rings"><i /><i /><i /></div>
            <motion.div className="hero-phone" style={reduce ? undefined : { rotate: tilt, y: lift }} inert>
              <PhoneFrame scale={scale}>
                <DemoApp tab={s.tab} scrollTo={s.scroll ?? 0} locked={!!s.locked} />
              </PhoneFrame>
            </motion.div>
          </div>
        </div>

        <ol className="dots" aria-label="Intro steps">
          {SLIDES.map((sl, i) => (
            <li key={sl.title}>
              <button type="button" className={i === step ? 'on' : ''} aria-label={`Step ${i + 1}: ${sl.tag ?? 'Welcome'}`} aria-current={i === step ? 'step' : undefined} onClick={() => goTo(i)} />
            </li>
          ))}
        </ol>

        <button type="button" className="cue" onClick={() => goTo(1)}>
          Scroll <Icon name="arrow" />
        </button>
        <a className="skip" href="#about">Skip intro</a>
      </div>
    </section>
  );
}
