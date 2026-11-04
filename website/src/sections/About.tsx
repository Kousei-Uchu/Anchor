import { FEATURES } from '../content/story';
import { Icon } from '../components/Icons';
import { Reveal } from '../components/Reveal';

export function About() {
  return (
    <section className="section" id="about">
      <Reveal>
        <p className="eyebrow">About</p>
        <h2>What Anchor is</h2>
        <p className="lead">
          A private companion for iPhone and iPad that keeps what you need on hard days in one place, written by you, ready when you are.
        </p>
      </Reveal>
      <div className="feature-grid">
        {FEATURES.map((f, i) => (
          <Reveal key={f.title} delay={(i % 3) * 0.08} className={`feature ${i % 2 ? 'sage' : ''}`}>
            <span className="feature-ic"><Icon name={f.icon} /></span>
            <h3>{f.title}</h3>
            <p>{f.body}</p>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
