import { createContext, useContext } from 'react';

/** A tiny navigation stack, like the NavigationStack each tab has in the app. Screens call push('contacts') to open a detail screen. */
export type Nav = { push: (screen: string) => void; pop: () => void };
export const NavContext = createContext<Nav>({ push: () => {}, pop: () => {} });
export const useNav = () => useContext(NavContext);
