import IosApp from '../components/ios/IosApp';

/**
 * Development preview of the rebuilt app. Only reachable while running `npm run dev`, at /demo-now.
 * ?tab=Plan opens a tab, ?dark switches to dark mode, ?full lays the whole screen out without scrolling.
 */
export default function DemoNow() {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get('tab') ?? 'Now';
  const tab = raw.charAt(0).toUpperCase() + raw.slice(1).toLowerCase();
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '96px 0 64px' }}>
      <IosApp initialTab={tab} scheme={params.has('dark') ? 'dark' : 'light'} full={params.has('full')} />
    </div>
  );
}
