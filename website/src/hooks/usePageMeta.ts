import { useEffect } from 'react';

/** Sets the tab title and meta description for the current route. */
export function usePageMeta(title: string, description: string) {
  useEffect(() => {
    document.title = title;
    let tag = document.querySelector<HTMLMetaElement>('meta[name="description"]');
    if (!tag) {
      tag = document.createElement('meta');
      tag.name = 'description';
      document.head.append(tag);
    }
    tag.content = description;
  }, [title, description]);
}
