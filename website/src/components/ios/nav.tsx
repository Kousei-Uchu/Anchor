import { createContext, useContext } from 'react';

/**
 * A tiny navigation stack, like the NavigationStack each tab has in the app. Screens call push('contacts') to open a detail screen
 * and present('checkin') to show a sheet. A screen that needs to know which thing was tapped takes an argument after "::",
 * for example push('loop::Waking in the night').
 */
export type Nav = { push: (screen: string) => void; pop: () => void; present: (sheet: string) => void; dismiss: () => void };
export const NavContext = createContext<Nav>({ push: () => {}, pop: () => {}, present: () => {}, dismiss: () => {} });
export const useNav = () => useContext(NavContext);
