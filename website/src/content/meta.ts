export const SITE_URL = 'https://anchor.aspens.page';
export const GITHUB_URL = 'https://github.com/Kousei-Uchu/Anchor';
export const SUPPORT_EMAIL = 'anchor@aspens.page';

export const ROUTE_META: Record<string, { title: string; description: string }> = {
  '/': {
    title: 'Anchor: a calm place for the hard days',
    description:
      'Anchor is a private safety plan, contacts and journal app for iPhone and iPad. No accounts, no tracking. Early build.',
  },
  '/about': {
    title: 'About Anchor',
    description: 'What Anchor is, what it holds to, what is new in each version, and how to reach me.',
  },
  '/features': {
    title: 'Anchor features',
    description: 'What each part of Anchor is for, written the same as the guide inside the app.',
  },
  '/philosophy': {
    title: 'Anchor philosophy',
    description: 'No scores, nothing sent for you, and local first. What Anchor is trying to be, and who it is and is not for.',
  },
  '/demo': {
    title: 'Anchor demo',
    description: 'A tappable demo of Anchor with made-up content. Nothing you type is saved or sent.',
  },
  '/privacy': { title: 'Anchor Privacy Policy', description: 'How Anchor handles your data.' },
  '/support': { title: 'Anchor Support', description: 'Help and contact for the Anchor app.' },
};
