import { Link } from 'react-router-dom';
import { Mascot } from '../components/Mascot';
import { usePageMeta } from '../hooks/usePageMeta';

export default function NotFound() {
  usePageMeta('Page not found · Anchor', 'That page does not exist.');
  return (
    <main className="prose center">
      <Mascot size={96} />
      <h1>That page isn&rsquo;t here.</h1>
      <p>No harm done. Let&rsquo;s head back.</p>
      <p><Link className="button" to="/">Back to Anchor</Link></p>
    </main>
  );
}
