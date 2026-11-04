/** One shared SVG sprite. Render <IconSprite /> once near the top of the app, then use <Icon name="…" /> anywhere. */
export function IconSprite() {
  return (
    <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden="true" focusable="false">
      <defs>
        <symbol id="anc" viewBox="0 0 100 112"><circle cx="50" cy="11" r="8.5" /><path d="M50 20V104M36 31H64M16 76C16 98 33 107 50 107S84 98 84 76M8 87L16 75L26 86M92 87L84 75L74 86" /></symbol>
        <symbol id="sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4" fill="currentColor" /><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" /></symbol>
        <symbol id="map" viewBox="0 0 24 24"><path d="M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14" /></symbol>
        <symbol id="pen" viewBox="0 0 24 24"><path d="M4 20l1-4L16 5l3 3L8 19zM14 7l3 3" /></symbol>
        <symbol id="swap" viewBox="0 0 24 24"><path d="M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4" /></symbol>
        <symbol id="chat" viewBox="0 0 24 24"><path d="M3 5h11v8H8l-3 3v-3H3zM17 9h4v8h-2v3l-3-3h-4v-2" /></symbol>
        <symbol id="msg" viewBox="0 0 24 24"><path d="M4 5h16v11H9l-5 4z" /></symbol>
        <symbol id="cal" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="16" rx="3" /><path d="M3 10h18M8 3v4M16 3v4" /></symbol>
        <symbol id="shield" viewBox="0 0 24 24"><path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z" /></symbol>
        <symbol id="ppl" viewBox="0 0 24 24"><circle cx="9" cy="8" r="3" /><circle cx="17" cy="9" r="2.5" /><path d="M3 19c0-3 3-5 6-5s6 2 6 5M16 14c3 0 5 2 5 5" /></symbol>
        <symbol id="clk" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></symbol>
        <symbol id="leaf" viewBox="0 0 24 24"><path d="M5 19C5 9 11 4 20 4c0 9-5 15-15 15zM5 19l8-8" /></symbol>
        <symbol id="lst" viewBox="0 0 24 24"><path d="M9 6h12M9 12h12M9 18h12M3 6l1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2" /></symbol>
        <symbol id="wind" viewBox="0 0 24 24"><path d="M3 9h11a3 3 0 10-3-3M3 14h15a3 3 0 11-3 3M3 19h7" /></symbol>
        <symbol id="spk" viewBox="0 0 24 24"><path d="M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2zM19 3v4M17 5h4" /></symbol>
        <symbol id="drv" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="7" rx="2" /><rect x="4" y="13" width="16" height="7" rx="2" /><path d="M8 7.5h.01M8 16.5h.01" /></symbol>
        <symbol id="hg" viewBox="0 0 24 24"><path d="M6 3h12M6 21h12M7 3c0 5 5 6 5 9s-5 4-5 9M17 3c0 5-5 6-5 9s5 4 5 9" /></symbol>
        <symbol id="doc" viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h7" /></symbol>
        <symbol id="clip" viewBox="0 0 24 24"><rect x="5" y="4" width="14" height="17" rx="2" /><path d="M9 3h6v3H9zM9 11h6M9 15h6" /></symbol>
        <symbol id="note" viewBox="0 0 24 24"><path d="M5 3h14v12l-6 6H5zM13 21v-6h6M8 8h8M8 12h5" /></symbol>
        <symbol id="loop" viewBox="0 0 24 24"><path d="M20 8a8 8 0 00-14-2M4 4v3h3M4 16a8 8 0 0014 2M20 20v-3h-3" /></symbol>
        <symbol id="net" viewBox="0 0 24 24"><circle cx="6" cy="7" r="2.5" /><circle cx="18" cy="7" r="2.5" /><circle cx="12" cy="18" r="2.5" /><path d="M8 8l3 8M16 8l-3 8M8.5 7h7" /></symbol>
        <symbol id="ml" viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="13" rx="2" /><path d="M3 8l9 6 9-6" /></symbol>
        <symbol id="sq" viewBox="0 0 24 24"><path d="M12 20h9M16 4l4 4L8 20H4v-4z" /></symbol>
        <symbol id="cog" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3" /><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" /></symbol>
        <symbol id="grid" viewBox="0 0 24 24"><circle cx="8" cy="7" r="2.5" /><circle cx="16" cy="7" r="2.5" /><circle cx="12" cy="13" r="2.5" /><circle cx="6" cy="18" r="2.5" /><circle cx="18" cy="18" r="2.5" /></symbol>
        <symbol id="phn" viewBox="0 0 24 24"><path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A15 15 0 013 6a2 2 0 012-2z" /></symbol>
        <symbol id="plus" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></symbol>
        <symbol id="sch" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4" /></symbol>
        <symbol id="lock" viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="10" rx="3" /><path d="M8 10V7a4 4 0 018 0v3" /></symbol>
        <symbol id="github" viewBox="0 0 24 24"><path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22" /></symbol>
        <symbol id="play" viewBox="0 0 24 24"><path d="M7 4.500v15l12-7.500z" fill="currentColor" /></symbol>
        <symbol id="arrow" viewBox="0 0 24 24"><path d="M12 5v14M6 13l6 6 6-6" /></symbol>
        <symbol id="check" viewBox="0 0 24 24"><path d="M5 12.500l4.500 4.500L19 7.500" /></symbol>
        <symbol id="menu" viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></symbol>
        <symbol id="close" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18" /></symbol>
      </defs>
    </svg>
  );
}

export function Icon({ name, className = 'ic' }: { name: string; className?: string }) {
  return (
    <svg className={className} aria-hidden="true" focusable="false">
      <use href={`#${name}`} />
    </svg>
  );
}
