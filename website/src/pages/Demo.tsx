import { Demo as DemoScreens, hasCapturedDemo } from '../components/CapturedDemo';
import { DEVICE_H, DEVICE_W, PhoneFrame } from '../components/PhoneFrame';
import { usePageMeta } from '../hooks/usePageMeta';
import { ROUTE_META } from '../content/meta';
import { useViewportSize } from '../hooks/useViewportSize';

export default function Demo() {
  usePageMeta(ROUTE_META['/demo'].title, ROUTE_META['/demo'].description);
  const { w, h } = useViewportSize();
  const scale = Math.max(0.45, Math.min(1.1, (w - 24) / DEVICE_W, (h - 150) / DEVICE_H));
  return (
    <main className="demo-page">
      <h1 className="sr-only">Anchor demo</h1>
      <p className="demo-note"><strong>Interactive demo.</strong>{' '}{hasCapturedDemo ? 'Real screens from the app, with made-up content. Tap around, and scroll with the wheel or a swipe.' : 'Rebuilt from the real app\u2019s screens, with made-up content.'} Nothing you type is saved or sent.</p>
      <PhoneFrame scale={scale}>
        <DemoScreens />
      </PhoneFrame>
    </main>
  );
}
