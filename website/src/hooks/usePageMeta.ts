import { useEffect } from 'react';

/** Sets the tab title and meta description for the current route, and a noindex tag when asked. */
export function usePageMeta(title: string, description: string, noindex = false) {
  useEffect(() => {
    document.title = title;
    let tag = document.querySelector<HTMLMetaElement>('meta[name="description"]');
    if (!tag) {
      tag = document.createElement('meta');
      tag.name = 'description';
      document.head.append(tag);
    }
    tag.content = description;
    let robots = document.querySelector<HTMLMetaElement>('meta[name="robots"]');
    if (noindex) {
      if (!robots) {
        robots = document.createElement('meta');
        robots.name = 'robots';
        document.head.append(robots);
      }
      robots.content = 'noindex, nofollow';
    } else {
      robots?.remove();
    }
  }, [title, description, noindex]);
}
