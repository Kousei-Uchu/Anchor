export const SITE_URL = 'https://anchor.aspens.page';
export const GITHUB_URL = 'https://github.com/Kousei-Uchu/Anchor';
export const SUPPORT_EMAIL = 'anchor@aspens.page';

export const ROUTE_META: Record<string, { title: string; description: string }> = {
  '/': {
    title: 'Anchor: a calm place for the hard days',
    description:
      'Anchor is a private safety plan, contacts and journal app for iPhone and iPad. No accounts, no tracking. Early build.',
  },
  '/demo': {
    title: 'Anchor demo',
    description: 'A tappable demo of Anchor with made-up content. Nothing you type is saved or sent.',
  },
  '/privacy': { title: 'Anchor Privacy Policy', description: 'How Anchor handles your data.' },
  '/support': { title: 'Anchor Support', description: 'Help and contact for the Anchor app.' },
};
