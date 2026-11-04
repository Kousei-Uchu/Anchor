import { GITHUB_URL } from '../content/meta';
import { Reveal } from '../components/Reveal';
import { Icon } from '../components/Icons';

export function Source() {
  return (
    <section className="section" id="source">
      <Reveal className="source">
        <h2>Open source</h2>
        <p className="lead">The code is on GitHub, so you can see exactly what Anchor does and doesn&rsquo;t do.</p>
        <p>
          <a className="button" href={GITHUB_URL}><Icon name="github" /> View on GitHub</a>
        </p>
      </Reveal>
    </section>
  );
}
