import { HeroStory } from '../sections/HeroStory';
import { About } from '../sections/About';
import { Showcase } from '../sections/Showcase';
import { Status } from '../sections/Status';
import { TryDemo } from '../sections/TryDemo';
import { Source } from '../sections/Source';
import { usePageMeta } from '../hooks/usePageMeta';
import { ROUTE_META } from '../content/meta';

export default function Home() {
  usePageMeta(ROUTE_META['/'].title, ROUTE_META['/'].description);
  return (
    <main>
      <HeroStory />
      <About />
      <Showcase />
      <Status />
      <TryDemo />
      <Source />
    </main>
  );
}
