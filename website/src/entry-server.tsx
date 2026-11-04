import { renderToString } from 'react-dom/server';
import { StaticRouter } from 'react-router-dom';
import { App } from './App';

export { ROUTE_META } from './content/meta';

/** Used at build time to write real HTML for each page, so privacy and support read fine without JavaScript. */
export function render(url: string) {
  return renderToString(
    <StaticRouter location={url}>
      <App />
    </StaticRouter>,
  );
}
