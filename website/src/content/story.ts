export type Slide = {
  tag?: string;
  title: string;
  body: string;
  /** Phone tab shown for this step, and how far its screen is scrolled. */
  tab: number;
  scroll?: number;
  locked?: boolean;
  /** Parallax for the two background glows, in vmax. */
  glow: [number, number, number, number];
  tilt: number;
  lift?: number;
};

export const SLIDES: Slide[] = [
  { title: 'A calm place for the hard days.', body: 'Your safety plan, your people and your journal. Private, on your phone.', tab: 0, glow: [0, 0, 0, 0], tilt: 0 },
  { tag: 'Plan', title: 'Your plan, in your words.', body: "Safety steps, triggers and scripts you wrote when you were okay, ready for when you aren't.", tab: 1, glow: [8, 6, -6, -4], tilt: -3 },
  { tag: 'Now', title: 'Your people, one tap away.', body: 'Trusted contacts, plus a lock screen widget so help is a tap, not a search.', tab: 0, scroll: 440, glow: [14, -4, -12, 6], tilt: 2, lift: -8 },
  { tag: 'Journal', title: 'Write at your pace.', body: 'A private journal with gentle suggestions from your day, only if you want them.', tab: 2, glow: [2, 10, -2, -10], tilt: -2 },
  { tag: 'Bridge', title: 'Walk into appointments ready.', body: 'Keep a running list of what to raise, and take your notes with you.', tab: 3, glow: [-8, 2, 8, 4], tilt: 3, lift: -6 },
  { tag: 'Private', title: 'Nothing leaves your phone on its own.', body: 'No account. No ads. No tracking. An optional Face ID lock.', tab: 0, locked: true, glow: [6, -8, -8, 8], tilt: 0 },
  { tag: 'Early build', title: 'Still being built.', body: "Anchor isn't finished and parts will change. The privacy promise won't.", tab: 0, glow: [0, 0, 0, 0], tilt: 0 },
];

export const FEATURES = [
  { icon: 'sun', title: 'Now', body: 'Crisis numbers for your region, a gentle check-in, your people, and grounding tools you wrote yourself.' },
  { icon: 'map', title: 'Plan', body: 'Safety plan, contacts, trigger windows, appointments, de-escalation scripts and affirmations.' },
  { icon: 'pen', title: 'Journal', body: 'A private timeline with Markdown, photos and drawings, with optional suggestions from your calendar, photos and music.' },
  { icon: 'swap', title: 'Bridge', body: 'Prepare for appointments, keep a list of things to raise, and export notes if you choose to share them.' },
  { icon: 'chat', title: 'Thread', body: "A message log, notes to your future self, things you haven't said yet, and a support calendar." },
  { icon: 'grid', title: 'Widgets', body: "Lock screen and home screen shortcuts to your top contacts, so you don't have to open the app." },
];
